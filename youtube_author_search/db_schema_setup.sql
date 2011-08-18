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
CREATE TABLE books
(
   books_id INTEGER primary key AUTOINCREMENT,
   author text not null,
   title text not null
);


CREATE INDEX book_index on books(author, title);

CREATE TABLE video_queries
(
   video_queries_id INTEGER primary key AUTOINCREMENT,
   channel text,
   search_type text,
   search_string text 
);

CREATE UNIQUE INDEX video_queries_index on video_queries(channel, search_type, search_string);

CREATE TABLE book_query_mapings
(
   book_query_mapings_id INTEGER primary key AUTOINCREMENT ,
   bookes_id INTEGER references books,
   video_queries_id INTEGER references video_queries
);
