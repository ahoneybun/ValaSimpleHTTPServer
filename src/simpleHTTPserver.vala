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
using Soup;
using App.Configs;
using Qrencode;


public class SimpleHTTPServer : Soup.Server {
        public string basedir;
        public uint port;
        public QRcode qrcode;

# if LIBSOUP30
        public signal void sig_directory_requested(Soup.ServerMessage msg, File file);
        public signal void sig_file_requested(Soup.ServerMessage msg, File file);
        public signal void sig_error(Soup.ServerMessage msg, File file);
# else
        public signal void sig_directory_requested(Soup.Message msg, File file);
        public signal void sig_file_requested(Soup.Message msg, File file);
        public signal void sig_error(Soup.Message msg, File file);
# endif
        public static bool log = false;
        public static bool add_modified_data = true;


        public SimpleHTTPServer () {
                this.with_port_and_path(8080, Environment.get_current_dir());
        }

        public SimpleHTTPServer.with_path(string path) {
                this.with_port_and_path(8080, path);
        }

       public SimpleHTTPServer.with_port(int port) {
                this.with_port_and_path(port, Environment.get_current_dir());
       }

        public SimpleHTTPServer.with_port_and_path(int port, string path) {
                assert (this != null);
                this.port = port;
                if (path == "" || path == "/") this.basedir = "/";
                else {
                    this.basedir = path;
                    if (this.basedir.get_char(this.basedir.length-1) != '/') this.basedir = this.basedir + "/";
                }
                this.add_early_handler(Constants.SERVER_STYLES_PATH, StylesHandler.handler);
                this.add_handler (null, default_handler);
                this.sig_directory_requested.connect(dir_handle);
                this.sig_file_requested.connect(file_handle);
                this.sig_error.connect(error_handle);
        }

        public void run_async() {
            this.listen_all(this.port, 0);
            this.qrcode = new QRcode.encodeString(this.get_link(), 0, EcLevel.H, Mode.B8, 1);
            this.print_qr();
            print(_("Server is listening on: ")+get_link()+"\n");
        }

        public void run() {
            log = true;
            MainLoop loop = new MainLoop ();
            this.listen_all(this.port, 0);
            this.qrcode = new QRcode.encodeString(this.get_link(), 0, EcLevel.H, Mode.B8, 1);
            this.print_qr();
            print(_("Server is listening on: ")+get_link()+"\n");
			loop.run ();
        }

        public void print_qr() {
            if (qrcode != null) {
                for (int iy = 0; iy < qrcode.width; iy++) {
                    for (int ix = 0; ix < qrcode.width; ix++) {
                        if ((qrcode.data[iy * qrcode.width + ix] & 1) != 0) {
                            print("\u2588\u2588");
                        }else{
                            print("  ");
                        }
                    }
                    print("\n");
                }
            }
        }

        private static string normalize_path(string path) {
            if (path == "/") return path;
            string normalized_path = "";
            foreach (string partial_path in path.split("/")) {
# if LIBSOUP30
                if (partial_path != "") normalized_path += "/%s".printf(GLib.Uri.escape_string(partial_path));
# else
                if (partial_path != "") normalized_path += "/%s".printf(Soup.URI.encode(partial_path, null));
#endif

            }
            // Caracters que el encode del URI no fa no se perque, ja que també son caracters especials...
            normalized_path = normalized_path.replace("!", "%21");
            normalized_path = normalized_path.replace("#", "%23");
            normalized_path = normalized_path.replace("$", "%24");
            normalized_path = normalized_path.replace("&", "%26");
            normalized_path = normalized_path.replace("'", "%27");
            normalized_path = normalized_path.replace("(", "%28");
            normalized_path = normalized_path.replace(")", "%29");
            normalized_path = normalized_path.replace("*", "%2A");
            normalized_path = normalized_path.replace("+",  "%2B");
            normalized_path = normalized_path.replace(",", "%2C");
            normalized_path = normalized_path.replace(":", "%3A");
            normalized_path = normalized_path.replace(";", "%3B");
            normalized_path = normalized_path.replace("=", "%3D");
            normalized_path = normalized_path.replace("?", "%3F");
            normalized_path = normalized_path.replace("@", "%40");
            normalized_path = normalized_path.replace("[", "%5B");
            normalized_path = normalized_path.replace("]", "%5D");
            //print("\nEncoded vs No encoded:|%s||%s|\n", normalized_path, path);
            return normalized_path;
        }
# if LIBSOUP30
        private static void default_handler (Server server, Soup.ServerMessage msg, string path, GLib.HashTable? query) {
# else
        private static void default_handler (Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
#endif
            // The default handler checks the type of the file requested (the file is calculated with basedir + request_path)
            // Then, if it is a directory sends the signal sig_directory_requested of server.
            // If it is a file sends the signal sig_file_requested of server.
            // And if the file doesn't exists sends the signal sig_erro of server
            unowned SimpleHTTPServer self = server as SimpleHTTPServer;
# if LIBSOUP30
            if (msg.get_uri().get_path() == "favicon.ico") return;
# else
            if (msg.uri.get_path() == "favicon.ico") return;
#endif
            string rel_path = msg.get_uri().get_path();
            File rfile;
            if (rel_path == "/" && self.basedir == "/")  rfile = File.new_for_path(rel_path);
            else  rfile = File.new_for_path(self.basedir+rel_path);
            //PRINT// stdout.printf("====================================================\nSTART of Request\n");
            var ftype = rfile.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            if (log) stdout.printf(_("Requested: %s, full path: %s\n"), rel_path, rfile.get_path());
# if LIBSOUP30
            msg.set_status(200, _("OK"));
# else
            msg.status_code = 200;
#endif
            print(_("Requested: ")+rel_path+"\n");
            // PRINT // stdout.printf("TYPE: %s\n", ftype.to_string());
            if (ftype == FileType.DIRECTORY) self.sig_directory_requested(msg, rfile);
            else if (ftype == FileType.REGULAR) self.sig_file_requested(msg, rfile);
            else self.sig_error(msg, rfile);
            //PRINT// stdout.printf("END of Request\n======================================================\n");
        }
# if LIBSOUP30
        private void dir_handle(Soup.ServerMessage msg, File file) {
# else
        private void dir_handle(Soup.Message msg, File file) {
#endif
            if (has_index(file)) this.send_index(msg, file);
            else this.send_list_dir(msg, file);
        }

# if LIBSOUP30
        private void file_handle(Soup.ServerMessage msg, File file) {
# else
        private void file_handle(Soup.Message msg, File file) {
#endif
            this.send_file(msg, file);
        }

# if LIBSOUP30
        private void error_handle(Soup.ServerMessage msg, File file) {
# else
        private void error_handle(Soup.Message msg, File file) {
#endif
            msg.set_response ("text/html", Soup.MemoryUse.COPY, "<html><meta charset=\"utf-8\"><title>404</title><body><h1>404</h1><p>File not found.</p></body></html>".data);
# if LIBSOUP30
            msg.set_status(404, _("Not Found"));
# else
            msg.status_code = 404;
#endif
        }

        private bool has_index(File file) {
            FileEnumerator enumerator = file.enumerate_children ("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
    	    FileInfo info = null;
    	    while (((info = enumerator.next_file (null)) != null)) {
    	        if (info.get_name () == "index.html") return true;
    	    }
            return false;
        }

# if LIBSOUP30
        private void send_index(Soup.ServerMessage msg, File file) {
# else
        private void send_index(Soup.Message msg, File file) {
#endif
            File index = File.new_for_path(file.get_path()+"/index.html");
            this.send_file(msg, index);
        }

# if LIBSOUP30
        private void send_list_dir(Soup.ServerMessage msg, File file) {
# else
        private void send_list_dir(Soup.Message msg, File file) {
#endif
            string newindex = """<html>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <link rel="stylesheet" href="%s">
                <body>
            """.printf(Constants.SERVER_STYLES_PATH);

            Gee.ArrayList<FileInfo> folders_list = new Gee.ArrayList<FileInfo>();
            Gee.ArrayList<FileInfo> files_list = new Gee.ArrayList<FileInfo>();

            File fbase = File.new_for_path(basedir);
            string base_rel_path = file.get_path().substring(fbase.get_path().length)+"/";
            newindex = _("%s<header><h1 title=\"%s\">Listing files of: %s</h1></header>").printf(newindex, base_rel_path, base_rel_path);

            if (fbase.get_path() != file.get_path() &&  file.has_parent(null)) {
                File parent = file.get_parent();
                string rel_path = parent.get_path().substring(fbase.get_path().length);
                if (rel_path == "") rel_path = "/";
                //PRINT// stdout.printf("Parent: %s\n", rel_path);
                newindex = "%s<div class=\"listing\">%s</div>".printf(newindex, add_item(rel_path, "../", null));
            }
            FileEnumerator enumerator = file.enumerate_children ("*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
            FileInfo info = null;

            newindex = "%s%s".printf(newindex, "<div class=\"listing\">");
            while (((info = enumerator.next_file (null)) != null)) {
                if (info.get_name().length > 0 && info.get_name()[0] == '.') continue;
                if (info.get_file_type () == FileType.DIRECTORY) folders_list.add(info);
                else files_list.add(info);
            }

            folders_list.sort(fileinfo_comparator);
            files_list.sort(fileinfo_comparator);

            // Render folders first
            folders_list.foreach((_info) => {
                newindex = "%s%s".printf(newindex, add_item(base_rel_path + _info.get_name(), null, _info));
                return true;
            });

            // Render files
            files_list.foreach((_info) => {
                newindex = "%s%s".printf(newindex, add_item(base_rel_path + _info.get_name(), null, _info));
                return true;
            });

            newindex = "%s</div></body></html>".printf(newindex);
            msg.set_response ("text/html", Soup.MemoryUse.COPY, newindex.data);
        }

        private static string add_item(string path, string? name, FileInfo? file_info) {
            string spath = name;
            var is_dir = false;
            var file_type = "file";

            if (file_info != null) {
                is_dir = file_info.get_file_type() == FileType.DIRECTORY;

                if (spath == null) {
                    if (path == "/") spath = "/";
                    else {
                        spath = path.split("/")[path.split("/").length-1];
                        if (is_dir) spath += "/";
                    }
                }

                // Detect filetype: file, image, audio, video, etc.
                var content_type = file_info.get_content_type();
                if (content_type.contains("image")) {
                    file_type = "image-file";
                }
                else if (content_type.contains("audio/")) {
                    file_type = "audio-file";
                } else if (content_type.contains("video/")){
                    file_type = "video-file";
                } else if (content_type.contains("text/")){
                    file_type = "text-file";
                } else if (content_type.contains("/zip") || content_type.contains("/gzip")) {
                    file_type = "archive-file";
                } 
            }
            string normalized_path = normalize_path(path);

            var string_builder = new StringBuilder("<div class=\"item\">");

            // Handle special "Upper" link
            if (name == "../") {
                string_builder.append_printf("<div class=\"icon opened-folder\"></div>");
            } else {
                //  Display icons for any other types
                string_builder.append_printf("<div class=\"icon %s\"></div>", is_dir ? "folder" : file_type);
            }
           
            string_builder.append_printf("<div class=\"name\"><a title=\"%s\" href=\"%s\">%s</a></div>", spath, normalized_path, spath);

            if (file_info != null) {
                string_builder.append_printf("<div class=\"size\">%s</div>", SimpleHTTPServer.bytes_to_string(file_info.get_size()));
                if (SimpleHTTPServer.add_modified_data) {
                    string_builder.append_printf("<div class=\"modified\" title=\"%s\">%s</div>",
                        file_info.get_modification_date_time().to_string(),
                        file_info.get_modification_date_time().format(Constants.DATE_FORMAT));
                }
            }

            string_builder.append("</div>");
            return string_builder.str;
        }

        private int fileinfo_comparator(FileInfo a, FileInfo b) {
            var a_name = a.get_name().down();
            var b_name = b.get_name().down();

            if (a_name > b_name) return 1;
            if (a_name < b_name) return -1;
            return 0;
        }

        public static string bytes_to_string(int64 size)
        {
            if (size == 0) {
                return "0 B";
            }
            string[] suf = { "B", "KB", "MB", "GB", "TB", "PB", "EB" }; //Longs run out around EB
            var power = 1024;
            var n = 0;
            while (size >= power) {
                size /= power;
                n++;
            }
            return "%s %s".printf(size.to_string(), suf[n]);
        }

# if LIBSOUP30
        private void send_file(Soup.ServerMessage msg, File file) {
# else
        private void send_file(Soup.Message msg, File file) {
#endif
            MainLoop loop = new MainLoop ();
            file.read_async.begin (Priority.DEFAULT, null, (obj, res) => {
                try {
                    size_t BUFFER_SIZE = 1024 * 4;
                    FileInputStream file_input_stream = file.read_async.end (res);
                    ssize_t bytes_read = 0;
                    uint8[] buffer = new uint8[BUFFER_SIZE];
                    string type = get_file_type(file);
                    Cancellable cancellable = new Cancellable ();
                    while ((bytes_read = file_input_stream.read (buffer, cancellable)) != 0) {
                        // Send the buffer content as needed
                        msg.set_response (type, Soup.MemoryUse.COPY, buffer[0:bytes_read]);
                    }
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                }
                loop.quit ();
            });
            loop.run ();
        }

        private static uint8[] get_file_content(File file) {
            uint8[] contents;
            string etag_out;
            try {
                try {
                    file.load_contents (null, out contents, out etag_out);
                }catch (Error e){
                    error("%s", e.message);
                }
            }catch (Error e){
                error("%s", e.message);
            }
            //PRINT//stderr.printf("CONTENT: %d ||%s||\nSTR: %d ||%s||\n", contents.length, (string) contents, ((string)contents).data.length, (string) (((string)contents).strip()).data);
            return contents;
        }

        private static string get_file_type(File file) {
            string res = "text/text";
            try {
                FileInfo inf = file.query_info("*", 0);
                res = inf.get_content_type();
            }catch (Error e){
                error("%s", e.message);
            }
            return res;
        }

        public string get_link() {
            return "http://"+resolve_server_address()+":"+this.port.to_string();
        }
        public string resolve_server_address() {
            try {
                // Resolve hostname to IP address
               var resolver = Resolver.get_default ();
               var addresses = resolver.lookup_by_name_with_flags("www.google.com", ResolverNameLookupFlags.IPV4_ONLY, null);
               var address = addresses.nth_data (0);

               var client = new SocketClient ();
               var conn = client.connect (new InetSocketAddress (address, 80));
               InetSocketAddress local = conn.get_local_address() as InetSocketAddress;
               return local.get_address().to_string();
            } catch (Error e){
                return "0.0.0.0";
            }
        }
        public uint get_port() {
            return this.port;
        }
        public void set_port(int nport) {
            this.port = nport;
        }

        // public static int main (string[] args) {
        //         SimpleHTTPServer server = new SimpleHTTPServer.with_path ("");
        //         server.run ();
        //         return 0;
        // }
}
