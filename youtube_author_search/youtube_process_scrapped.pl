#!/usr/bin/perl -w

use Feed::Find;
use Data::Dumper;
use Encode;
use LWP::UserAgent;
use XML::LibXML;
use Carp;
#use XML::LibXML::Enhanced;

use youtube_utils;

use DBIx::Simple;

use List::MoreUtils qw{
  any all none notall true false
  firstidx first_index lastidx last_index
  insert_after insert_after_string
  apply indexes
  after after_incl before before_incl
  firstval first_value lastval last_value
  each_array each_arrayref
  pairwise natatime
  mesh zip uniq  minmax part
};

use 5.10.0;

use strict;
use warnings;


sub process_raw_xml
{
    my $db = youtube_utils::_get_db();

    my $youtube_videos_raw_xml = $db->query( " select * from youtube_videos_raw_xml " )->hashes();

    my $videos_processed = 0;
    my $total_videos   = scalar ( @$youtube_videos_raw_xml );

    foreach my $youtube_video_raw_xml ( @$youtube_videos_raw_xml )
    {
        my $full_xml_string = $youtube_video_raw_xml->{ full_xml_string };
	
	my $dom = XML::LibXML->load_xml( string => $full_xml_string );

	my $entry = $dom->documentElement();

	my $hash = youtube_utils::_get_data_hash_from_youtube_video_entry( $entry );

	#say Dumper ( $hash );

	 youtube_utils::store_video_in_db( $hash );

	 $videos_processed++;

	if ( ($videos_processed % 100 ) == 0 )
	{
	   say STDERR "Processed $videos_processed out of $total_videos";
	}
    }
}


sub main
{
    process_raw_xml();
}

main();
