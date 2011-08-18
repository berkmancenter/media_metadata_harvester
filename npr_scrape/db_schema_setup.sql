CREATE TABLE npr_items_raw
(
	npr_item_id INTEGER primary key AUTOINCREMENT,
	id  text not null,
	full_xml_string text not null
);

CREATE TABLE npr_items_processed
(
	npr_item_id INTEGER primary key AUTOINCREMENT,
	id  text not null,
audio_description text ,
audio_duration text ,
audio_format_mp3 text ,
audio_format_rm text ,
audio_format_wm text ,
byline_name text ,
correction_correctionDate text ,
correction_correctionText text ,
correction_correctionTitle text ,
keywords text ,
lastModifiedDate text ,
miniTeaser text ,
organization_name text ,
organization_website text ,
priorityKeywords text ,
pubDate text ,
shortTitle text ,
slug text ,
storyDate text ,
subtitle text ,
teaser text ,
text text,
thumbnail_large text ,
thumbnail_medium text ,
thumbnail_provider text ,
bookEdition_isbn text ,
bookEdition_book_title text ,
bookEdition_publisher text ,
bookEdition_format text ,
bookEdition_pubDate text ,
bookEdition_pagination text ,
bookEdition_listPrice text ,
title text ,
toenail text ,
toenail_medium text 
);

