import sqlite3
import shutil


conn = sqlite3.connect("navidrome.db")
shutil.copy("navidrome.db", "navidrome.db.bak")

cur = conn.cursor()

cur.execute("SELECT id, name FROM playlist")
playlists = cur.fetchall()

for playlist in playlists:
    if playlist[1] == "0":
        cur.execute("SELECT id FROM media_file")
        all_songs = cur.fetchall()
        if not all_songs:
            continue
        cur.execute(
            "SELECT item_id FROM annotation WHERE item_type = 'media_file' AND rating NOT LIKE '0'",
        )
        blacklist = cur.fetchall()
        songs = [song for song in all_songs if song not in blacklist]
    elif playlist[1] not in ["2", "3", "4", "5"]:
        continue
    else:
        cur.execute(
            "SELECT item_id FROM annotation WHERE item_type = 'media_file' AND rating = ?",
            (playlist[1],),
        )
        songs = cur.fetchall()
    if not songs:
        continue
    print(f"Playlist: {playlist[1]} ({len(songs)} songs)")
    for i, song in enumerate(songs, start=1):
        cur.execute(
            "REPLACE INTO playlist_tracks (id, playlist_id, media_file_id) VALUES (?, ?, ?)",
            (i, playlist[0], song[0]),
        )
    # Update the song_count in the playlist
    cur.execute(
        "UPDATE playlist SET song_count = ? WHERE id = ?",
        (len(songs), playlist[0]),
    )

conn.commit()
conn.close()