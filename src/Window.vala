/*
* Copyright (C) 2018  Eduard Berloso Clarà <eduard.bc.95@gmail.com>
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as published
* by the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*/

using Hdy;
using App.Configs;
using App.Widgets;
using App.Views;

namespace App {

    /**
     * Class responsible for creating the window and will contain contain other widgets.
     * allowing the user to manipulate the window (resize it, move it, close it, ...).
     *
     * @see Hdy.ApplicationWindow
     * @since 1.0.0
     */
    public class AppWindow : Hdy.ApplicationWindow {
    
        private Gtk.Box main_box;
        private Gtk.Widget current_view;
        public AppHeaderBar headerbar;
        private AppSettings saved_state;

        /**
         * Constructs a new {@code AppWindow} object.
         *
         * @see App.Configs.Constants
         * @see style_provider
         * @see build
         */
        public AppWindow (Gtk.Application app) {
            Object (
                application: app,
                icon_name: Constants.APP_ICON,
                resizable: true
            );

            Hdy.init ();

            this.main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            this.add(this.main_box);

            // Set the custom headerbar
            this.headerbar = new AppHeaderBar (true);
            this.main_box.pack_start(this.headerbar, false, false, 0);
            this.init_css ();
            this.load_window_state ();
            this.set_min_size(600, 400);
            this.delete_event.connect (save_window_state);

            var granite_settings = Granite.Settings.get_default ();
            var gtk_settings = Gtk.Settings.get_default ();

            // Check whether the theme is dark or not
            var is_dark_mode = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            if (is_dark_mode) {
                this.get_style_context().add_class("dark-mode");
            }
            gtk_settings.gtk_application_prefer_dark_theme = is_dark_mode;

            // Handle Granite's theme changes. Usefull for elementary OS.
            granite_settings.notify["prefers-color-scheme"].connect (() => {
                var _dark_mode = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
                
                this.get_style_context().remove_class("dark-mode");
                if (_dark_mode) {
                    this.get_style_context().add_class("dark-mode");
                }
            });

            // Handle GTK's theme changes, usefull for GNOME.
            gtk_settings.notify["gtk-application-prefer-dark-theme"].connect(() => {
                var _dark_mode = gtk_settings.gtk_application_prefer_dark_theme;
                this.get_style_context().remove_class("dark-mode");
                if (_dark_mode) {
                    this.get_style_context().add_class("dark-mode");
                }
            });
       }

        public void init() {
            this.show_all ();
        }

        public void set_min_size(int w, int h) {
            var geometry = Gdk.Geometry () {
                min_width = w,
                max_width = -1,
                min_height = h,
                max_height = -1
            };
            this.set_geometry_hints (this, geometry, Gdk.WindowHints.MIN_SIZE);
        }

        public void clean() {
            if (this.current_view != null) {
                this.main_box.remove(this.current_view);
                this.current_view = null;
            }
        }

        public void add_view (Gtk.Widget view) {
            this.current_view = view;
            this.main_box.pack_start (view, true, true, 0);
        }

        private void init_css() {
            // Load CSS
            var provider = new Gtk.CssProvider();
            try {
                provider.load_from_resource("/com/github/bcedu/resources/com.github.bcedu.valasimplehttpserver.css");
                Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                stderr.printf("\nError: %s\n", e.message);
            }
        }

        private void load_window_state() {
            this.saved_state = AppSettings.get_default();
            // Load size
            this.set_default_size (this.saved_state.window_width, this.saved_state.window_height);
            // Load position
            this.move (this.saved_state.window_posx, this.saved_state.window_posy);
            // Maximize window if necessary
            if (this.saved_state.window_state == 1) this.maximize ();
            // Load position
            this.set_position (Gtk.WindowPosition.CENTER);
        }

        private bool save_window_state(Gdk.EventAny event) {
            int aux1;
            int aux2;
            this.get_size (out aux1, out aux2);
            saved_state.window_width = aux1;
            saved_state.window_height = aux2;
            this.get_position (out aux1, out aux2);
            saved_state.window_posx = aux1;
            saved_state.window_posy = aux2;
            if (this.is_maximized) saved_state.window_state = 1;
            else saved_state.window_state = 0;
            return false;
        }

    }
}
