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
	keywords text ,
	lastModifiedDate text ,
	miniTeaser text ,
	priorityKeywords text ,
	pubDate text ,
	shortTitle text ,
	slug text ,
	storyDate text ,
	subtitle text ,
	teaser text ,
	title text
);

