public class Fragments.TorrentManager{

	private Transmission.variant_dict settings;
	private Transmission.Session session;

        private static string CONFIG_DIR = GLib.Path.build_path(GLib.Path.DIR_SEPARATOR_S, Environment.get_user_config_dir(), "fragments");

	public TorrentModel queued_torrents;
	public TorrentModel downloading_torrents;
	public TorrentModel seeding_torrents;

        public TorrentManager(){
		Transmission.String.Units.mem_init(1024, _("KB"), _("MB"), _("GB"), _("TB"));
		Transmission.String.Units.speed_init(1024, _("KB/s"), _("MB/s"), _("GB/s"), _("TB/s"));

                settings = Transmission.variant_dict(0);
                Transmission.load_default_settings(ref settings, CONFIG_DIR, "fragments");

                session = new Transmission.Session(CONFIG_DIR, false, settings);
                if(App.settings.download_folder == "") App.settings.download_folder = Environment.get_user_special_dir(GLib.UserDirectory.DOWNLOAD);

		queued_torrents = new TorrentModel();
		downloading_torrents = new TorrentModel();
		seeding_torrents = new TorrentModel();

		update_transmission_settings();
		connect_signals();
        }

        private void connect_signals(){
		App.settings.notify["max-downloads"].connect(update_transmission_settings);
        }

        private void update_transmission_settings(){
                settings.add_int (Transmission.Prefs.download_queue_size, App.settings.max_downloads);
		session.update_settings (settings);

        }

        public void restore_torrents(){
		var torrent_constructor = new Transmission.TorrentConstructor (session);
		unowned Transmission.Torrent[] transmission_torrents = session.load_torrents (torrent_constructor);
                for (int i = 0; i < transmission_torrents.length; i++) {
                	var torrent = new Torrent(transmission_torrents[i]);
                	torrent.notify["activity"].connect(() => { update_torrent(torrent); });
			update_torrent(torrent);
		}
        }

	public bool add_torrent_by_path(string path){
		message("Adding torrent by file \"%s\"...", path);

		var torrent_constructor = new Transmission.TorrentConstructor (session);
		torrent_constructor.set_metainfo_from_file (path);
		add_torrent(ref torrent_constructor);

		return false;
	}

	public bool add_torrent_by_magnet(string magnet){
		message("Adding torrent by magnet link \"%s\"...", magnet);

		var torrent_constructor = new Transmission.TorrentConstructor (session);
		torrent_constructor.set_metainfo_from_magnet_link (magnet);
		add_torrent(ref torrent_constructor);

		return false;
	}

	private void add_torrent(ref Transmission.TorrentConstructor torrent_constructor){
		torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, App.settings.download_folder);

		Transmission.ParseResult result;
		int duplicate_id;
		unowned Transmission.Torrent torrent = torrent_constructor.instantiate (out result, out duplicate_id);

		if (result == Transmission.ParseResult.OK) {
			var ftorrent = new Fragments.Torrent(torrent);
			ftorrent.notify["activity"].connect(() => { update_torrent(ftorrent); });
			update_torrent(ftorrent);
		}
		message("Result: %s", result.to_string());
	}

	private void update_torrent(Torrent torrent){
		if(torrent.activity == Transmission.Activity.SEED || torrent.activity == Transmission.Activity.SEED_WAIT){
			if(seeding_torrents.contains_torrent(torrent)) return;
			else{
				if(downloading_torrents.contains_torrent(torrent)) downloading_torrents.remove_torrent(torrent);
				if(queued_torrents.contains_torrent(torrent)) queued_torrents.remove_torrent(torrent);
				seeding_torrents.add_torrent(torrent);
			}
		}else if(torrent.activity == Transmission.Activity.DOWNLOAD){
			if(downloading_torrents.contains_torrent(torrent)) return;
			else{
				if(seeding_torrents.contains_torrent(torrent)) seeding_torrents.remove_torrent(torrent);
				if(queued_torrents.contains_torrent(torrent)) queued_torrents.remove_torrent(torrent);
				downloading_torrents.add_torrent(torrent);
			}
		}else{
			if(queued_torrents.contains_torrent(torrent)) return;
			else{
				if(seeding_torrents.contains_torrent(torrent)) seeding_torrents.remove_torrent(torrent);
				if(downloading_torrents.contains_torrent(torrent)) downloading_torrents.remove_torrent(torrent);
				queued_torrents.add_torrent(torrent);
			}
		}
	}
}
