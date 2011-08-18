CREATE TABLE youtube_videos_raw_xml
(
	youtube_videos_raw_xml_id INTEGER primary key AUTOINCREMENT,
	id  text not null,
	full_xml_string text not null
)
;


CREATE TABLE youtube_videos
(
	youtube_videos_id INTEGER primary key AUTOINCREMENT,
	id  text not null,
	title text not null,
	description text not null,
	full_string text not null,
	channel text not null,
	rating_average integer ,
	rating_min     integer ,
	rating_max     integer ,
	rating_numRaters integer,
	keywords text,
	duration_seconds         integer not null
)
;
