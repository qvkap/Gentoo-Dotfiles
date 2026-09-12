#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <gio/gio.h>

#define DEFAULT_COVER_TMP "/tmp/nowplaying_cover_dl.jpg"

typedef struct {
    char *bus_name;
    char *player_name;
    char *playback_status;
    char *title;
    char *artist;
    char *album;
    char *art_url;
} PlayerInfo;

static struct termios orig_termios;
static int raw_mode_enabled = 0;
static volatile sig_atomic_t need_redraw = 1;
static volatile sig_atomic_t running = 1;

static void disable_raw_mode(void) {
    if (raw_mode_enabled) {
        printf("\033[?25h\033[?1049l");
        fflush(stdout);
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
        raw_mode_enabled = 0;
    }
}

static void enable_raw_mode(void) {
    if (!isatty(STDIN_FILENO)) return;
    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(disable_raw_mode);

    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);

    printf("\033[?1049h\033[H\033[?25l");
    fflush(stdout);
    raw_mode_enabled = 1;
}

static void handle_sigwinch(int sig) {
    (void)sig;
    need_redraw = 1;
}

static void handle_sigint(int sig) {
    (void)sig;
    running = 0;
}

static void free_player_info(PlayerInfo *info) {
    if (!info) return;
    g_free(info->bus_name);
    g_free(info->player_name);
    g_free(info->playback_status);
    g_free(info->title);
    g_free(info->artist);
    g_free(info->album);
    g_free(info->art_url);
    memset(info, 0, sizeof(*info));
}

static gboolean get_player_info(GDBusConnection *conn, const char *bus_name, PlayerInfo *info) {
    memset(info, 0, sizeof(*info));
    info->bus_name = g_strdup(bus_name);

    const char *prefix = "org.mpris.MediaPlayer2.";
    if (g_str_has_prefix(bus_name, prefix)) {
        info->player_name = g_strdup(bus_name + strlen(prefix));
    } else {
        info->player_name = g_strdup(bus_name);
    }

    GError *error = NULL;
    GVariant *result = g_dbus_connection_call_sync(
        conn,
        bus_name,
        "/org/mpris/MediaPlayer2",
        "org.freedesktop.DBus.Properties",
        "GetAll",
        g_variant_new("(s)", "org.mpris.MediaPlayer2.Player"),
        G_VARIANT_TYPE("(a{sv})"),
        G_DBUS_CALL_FLAGS_NONE,
        1500,
        NULL,
        &error
    );

    if (!result) {
        if (error) g_error_free(error);
        free_player_info(info);
        return FALSE;
    }

    GVariant *dict = NULL;
    g_variant_get(result, "(@a{sv})", &dict);

    GVariant *status_var = g_variant_lookup_value(dict, "PlaybackStatus", G_VARIANT_TYPE_STRING);
    if (status_var) {
        info->playback_status = g_strdup(g_variant_get_string(status_var, NULL));
        g_variant_unref(status_var);
    } else {
        info->playback_status = g_strdup("Unknown");
    }

    GVariant *meta_var = g_variant_lookup_value(dict, "Metadata", G_VARIANT_TYPE_VARDICT);
    if (meta_var) {
        GVariant *val = g_variant_lookup_value(meta_var, "xesam:title", G_VARIANT_TYPE_STRING);
        if (val) {
            info->title = g_strdup(g_variant_get_string(val, NULL));
            g_variant_unref(val);
        }

        val = g_variant_lookup_value(meta_var, "xesam:album", G_VARIANT_TYPE_STRING);
        if (val) {
            info->album = g_strdup(g_variant_get_string(val, NULL));
            g_variant_unref(val);
        }

        val = g_variant_lookup_value(meta_var, "mpris:artUrl", G_VARIANT_TYPE_STRING);
        if (val) {
            info->art_url = g_strdup(g_variant_get_string(val, NULL));
            g_variant_unref(val);
        }

        val = g_variant_lookup_value(meta_var, "xesam:artist", NULL);
        if (val) {
            if (g_variant_is_of_type(val, G_VARIANT_TYPE_STRING_ARRAY)) {
                gsize n = 0;
                const gchar **arr = g_variant_get_strv(val, &n);
                if (n > 0) {
                    info->artist = g_strjoinv(", ", (gchar **)arr);
                }
                g_free(arr);
            } else if (g_variant_is_of_type(val, G_VARIANT_TYPE_STRING)) {
                info->artist = g_strdup(g_variant_get_string(val, NULL));
            }
            g_variant_unref(val);
        }

        g_variant_unref(meta_var);
    }

    g_variant_unref(dict);
    g_variant_unref(result);

    return (info->title != NULL || info->art_url != NULL);
}

static char *resolve_artwork(const char *art_url) {
    if (!art_url || strlen(art_url) == 0) return NULL;

    if (g_str_has_prefix(art_url, "file://")) {
        GError *err = NULL;
        char *path = g_filename_from_uri(art_url, NULL, &err);
        if (path) return path;
        if (err) g_error_free(err);
        return g_strdup(art_url + 7);
    }

    if (g_str_has_prefix(art_url, "http://") || g_str_has_prefix(art_url, "https://")) {
        char cmd[1024];
        snprintf(cmd, sizeof(cmd), "curl -s -L -f --max-time 4 -o \"%s\" \"%s\"", DEFAULT_COVER_TMP, art_url);
        int res = system(cmd);
        if (res == 0 && access(DEFAULT_COVER_TMP, R_OK) == 0) {
            return g_strdup(DEFAULT_COVER_TMP);
        }
    }

    return NULL;
}

static void send_mpris_cmd(GDBusConnection *conn, const char *bus_name, const char *action) {
    if (!conn || !bus_name) return;
    g_dbus_connection_call(
        conn,
        bus_name,
        "/org/mpris/MediaPlayer2",
        "org.mpris.MediaPlayer2.Player",
        action,
        NULL,
        NULL,
        G_DBUS_CALL_FLAGS_NONE,
        1000,
        NULL,
        NULL,
        NULL
    );
}

static void print_centered(const char *text, int cols, const char *color_prefix, const char *color_suffix) {
    int len = (int)g_utf8_strlen(text, -1);
    int pad = (cols - len) / 2;
    if (pad < 0) pad = 0;
    for (int i = 0; i < pad; i++) putchar(' ');
    if (color_prefix) printf("%s", color_prefix);
    printf("%s", text);
    if (color_suffix) printf("%s", color_suffix);
    printf("\n");
}

int main(int argc, char **argv) {
    int once_mode = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--once") == 0 || strcmp(argv[i], "-1") == 0) {
            once_mode = 1;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            printf("Usage: %s [options]\n", argv[0]);
            printf("Options:\n");
            printf("  --once, -1     Single output without TUI mode\n");
            printf("  -h, --help     Show help\n");
            printf("\nKeybindings:\n");
            printf("  Space          Play / Pause\n");
            printf("  n              Next track\n");
            printf("  p              Previous track\n");
            printf("  q, Esc         Quit\n");
            return 0;
        }
    }

    if (!isatty(STDOUT_FILENO)) once_mode = 1;

    GError *error = NULL;
    GDBusConnection *conn = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!conn) {
        fprintf(stderr, "Failed to connect to D-Bus: %s\n", error ? error->message : "unknown");
        if (error) g_error_free(error);
        return 1;
    }

    if (!once_mode) {
        enable_raw_mode();
        signal(SIGWINCH, handle_sigwinch);
        signal(SIGINT, handle_sigint);
        signal(SIGTERM, handle_sigint);
    }

    PlayerInfo current_player;
    memset(&current_player, 0, sizeof(current_player));
    char last_title[512] = {0};
    char last_status[64] = {0};

    while (running) {
        GVariant *reply = g_dbus_connection_call_sync(
            conn,
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "ListNames",
            NULL,
            G_VARIANT_TYPE("(as)"),
            G_DBUS_CALL_FLAGS_NONE,
            1500,
            NULL,
            &error
        );

        PlayerInfo chosen;
        memset(&chosen, 0, sizeof(chosen));
        gboolean found = FALSE;

        if (reply) {
            gchar **names = NULL;
            g_variant_get(reply, "(^as)", &names);
            for (int i = 0; names && names[i]; i++) {
                if (g_str_has_prefix(names[i], "org.mpris.MediaPlayer2.")) {
                    PlayerInfo candidate;
                    if (get_player_info(conn, names[i], &candidate)) {
                        if (!found) {
                            chosen = candidate;
                            found = TRUE;
                        } else if (candidate.playback_status && g_strcmp0(candidate.playback_status, "Playing") == 0) {
                            free_player_info(&chosen);
                            chosen = candidate;
                        } else {
                            free_player_info(&candidate);
                        }
                    }
                }
            }
            g_strfreev(names);
            g_variant_unref(reply);
        } else if (error) {
            g_error_free(error);
            error = NULL;
        }

        if (found) {
            const char *t = chosen.title ? chosen.title : "";
            const char *s = chosen.playback_status ? chosen.playback_status : "";
            if (strcmp(t, last_title) != 0 || strcmp(s, last_status) != 0) {
                snprintf(last_title, sizeof(last_title), "%s", t);
                snprintf(last_status, sizeof(last_status), "%s", s);
                need_redraw = 1;
            }
        }

        if (need_redraw) {
            need_redraw = 0;

            struct winsize ws;
            if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
                ws.ws_col = 80;
                ws.ws_row = 24;
            }

            if (!once_mode) {
                printf("\033[H\033[2J");
            }

            if (!found) {
                if (!once_mode) {
                    int top_pad = ws.ws_row / 2 - 1;
                    for (int i = 0; i < top_pad; i++) putchar('\n');
                    print_centered("No active MPRIS player found", ws.ws_col, "\033[1;33m", "\033[0m");
                    print_centered("Press [q] to exit", ws.ws_col, "\033[38;5;242m", "\033[0m");
                } else {
                    printf("No active MPRIS player found.\n");
                }
                fflush(stdout);
            } else {
                int max_h = ws.ws_row - 8;
                if (max_h < 4) max_h = 4;

                int max_w = (int)(ws.ws_col * 0.65);
                if (max_w > 56) max_w = 56;
                if (max_w < 10) max_w = 10;

                int cover_h = max_h;
                int cover_w = cover_h * 2;

                if (cover_w > max_w) {
                    cover_w = max_w;
                    cover_h = cover_w / 2;
                }

                if (cover_h > 18) {
                    cover_h = 18;
                    cover_w = cover_h * 2;
                }
                if (cover_h < 4) cover_h = 4;
                if (cover_w < 8) cover_w = 8;

                char *local_cover = resolve_artwork(chosen.art_url);
                int cover_lines_count = 0;
                char **cover_lines = NULL;

                if (local_cover && access(local_cover, R_OK) == 0) {
                    char chafa_cmd[1024];
                    snprintf(chafa_cmd, sizeof(chafa_cmd), "chafa --format symbols --symbols vhalf+quad+space --colors 256 --size %dx%d \"%s\" 2>/dev/null", cover_w, cover_h, local_cover);
                    FILE *fp = popen(chafa_cmd, "r");

                    if (fp) {
                        char buf[4096];
                        cover_lines = malloc(sizeof(char *) * 128);
                        while (fgets(buf, sizeof(buf), fp) && cover_lines_count < 120) {
                            size_t l = strlen(buf);
                            while (l > 0 && (buf[l-1] == '\n' || buf[l-1] == '\r')) {
                                buf[--l] = '\0';
                            }
                            cover_lines[cover_lines_count++] = strdup(buf);
                        }
                        pclose(fp);
                    }
                }

                int total_height = cover_lines_count + 5;
                int top_pad = (ws.ws_row - total_height) / 2;

                if (top_pad < 1) top_pad = 1;
                if (once_mode) top_pad = 0;

                for (int i = 0; i < top_pad; i++) putchar('\n');

                int h_pad = (ws.ws_col - cover_w) / 2;
                if (h_pad < 0) h_pad = 0;

                for (int i = 0; i < cover_lines_count; i++) {
                    for (int p = 0; p < h_pad; p++) putchar(' ');
                    printf("%s\033[0m\n", cover_lines[i]);
                    free(cover_lines[i]);
                }
                free(cover_lines);
                g_free(local_cover);

                putchar('\n');

                char line1[512], line2[512], line3[512];

                const char *status_str = chosen.playback_status ? chosen.playback_status : "STOPPED";
                const char *status_col = "\033[33m";
                if (g_ascii_strcasecmp(status_str, "Playing") == 0) {
                    status_col = "\033[1;32m";
                }

                snprintf(line1, sizeof(line1), "[%s]  %s", status_str, chosen.title ? chosen.title : "Unknown Title");
                print_centered(line1, ws.ws_col, status_col, "\033[0m");

                if (chosen.artist && strlen(chosen.artist) > 0) {
                    snprintf(line2, sizeof(line2), "Artist: %s", chosen.artist);
                    print_centered(line2, ws.ws_col, "\033[1;36m", "\033[0m");
                }

                if (chosen.album && strlen(chosen.album) > 0) {
                    snprintf(line3, sizeof(line3), "Album: %s", chosen.album);
                    print_centered(line3, ws.ws_col, "\033[38;5;250m", "\033[0m");
                }

                if (!once_mode) {
                    putchar('\n');
                    print_centered("[Space] Play/Pause   [n] Next   [p] Prev   [q] Quit", ws.ws_col, "\033[38;5;239m", "\033[0m");
                }

                fflush(stdout);
            }
        }

        free_player_info(&current_player);
        current_player = chosen;

        if (once_mode) {
            break;
        }

        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(STDIN_FILENO, &fds);
        struct timeval tv = {0, 400000};

        int sel = select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv);
        if (sel > 0 && FD_ISSET(STDIN_FILENO, &fds)) {
            char c = 0;
            if (read(STDIN_FILENO, &c, 1) > 0) {
                if (c == 'q' || c == 'Q' || c == 27) {
                    break;
                } else if (c == ' ') {
                    if (current_player.bus_name) {
                        send_mpris_cmd(conn, current_player.bus_name, "PlayPause");
                        need_redraw = 1;
                    }
                } else if (c == 'n' || c == 'N') {
                    if (current_player.bus_name) {
                        send_mpris_cmd(conn, current_player.bus_name, "Next");
                        need_redraw = 1;
                    }
                } else if (c == 'p' || c == 'P') {
                    if (current_player.bus_name) {
                        send_mpris_cmd(conn, current_player.bus_name, "Previous");
                        need_redraw = 1;
                    }
                }
            }
        }
    }

    free_player_info(&current_player);
    g_object_unref(conn);

    if (!once_mode) {
        disable_raw_mode();
    }

    return 0;
}
