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

sub look_up_youtube_author_talk
{
    my ( $author, $channel ) = @_;

    my $base_url = "http://gdata.youtube.com/feeds/api/users/$channel/uploads";

    return _youtube_lookup( $base_url );
}

sub look_up_youtube_global
{
    my ( $author ) = @_;

    my $youtube_global_search_api = 'https://gdata.youtube.com/feeds/api/videos';
    return _youtube_lookup( $author, $youtube_global_search_api );
}

my $channel_author_counts = {};

sub _youtube_lookup
{
    my ( $base_url ) = @_;

    say "_youtube_lookup '$base_url'";

    confess unless $base_url;

    my $uri = URI->new( $base_url );

    # max size

    my $start_index = 1;

    my $max_results = 50;

    my $num_results;

    do
    {

        say "Requesting'$base_url' : start_index: $start_index max-results: $max_results";

        $uri->query_form( { 'start-index' => $start_index, 'max-results' => $max_results, prettyprint => 'true' } );

        # Create a request
        my $req = HTTP::Request->new( GET => $uri );

        my $ua = LWP::UserAgent->new;

        # Pass request to the user agent and get a response back
        my $res = $ua->request( $req );

        die unless $res->is_success;

        #say 'URL final = ' . $res->request->uri;
        my $content = $res->content;

        my $dom = XML::LibXML->load_xml( string => $content );

        my $xc = XML::LibXML::XPathContext->new( $dom );

        #'http://a9.com/-/spec/opensearchrss/1.0/

        my @nodes = $xc->findnodes( '//openSearch:totalResults' );

        $xc->registerNs( 'a', 'http://www.w3.org/2005/Atom' );
        my $totalResults_node = $nodes[ 0 ];

        die unless $totalResults_node;

        $num_results = $totalResults_node->textContent();

        #say "$num_results nodes for author: $author in $channel";

        die unless $num_results;

        my @entries = $xc->findnodes( '//a:entry' );

        foreach my $entry ( @entries )
        {

	   youtube_utils::store_raw_xml_for_video( $entry );

        }

        $start_index += $max_results;
    } while ( $start_index <= $num_results );

    return;
}

sub look_up_ted_talk_author
{
    my ( $author ) = @_;

    return look_up_youtube_author_talk( $author, 'TEDtalksDirector' );
}

sub look_up_berkman
{
    my ( $author ) = @_;

    return look_up_youtube_author_talk( $author, 'BerkmanCenter' );
}

sub look_up_BookTV
{
    my ( $author ) = @_;

    return look_up_youtube_author_talk( $author, 'BookTV' );
}

sub look_up_at_google_talks
{
    my ( $author ) = @_;

    return look_up_youtube_author_talk( $author, 'AtGoogleTalks' );
}

sub get_book_db_record
{
    my ( $title, $author ) = @_;

    my $dbh = _get_db();

    my $results = $dbh->query( " SELECT * from books where author = ? and title = ?  limit 1", $author, $title );

    #say Dumper ( $results );

    my $ret = $results->hashes;

    #say Dumper( $ret );

    #say Dumper( scalar( @$ret ) );

    if ( !scalar( @$ret ) )
    {
        $dbh->query( "INSERT INTO books (author, title) VALUES (?, ? ) ", $author, $title );
        $results = $dbh->query( " SELECT * from books where author = ? and title = ?  limit 1", $author, $title );
    }

    return $results->hash;
}

sub process_raw_xml
{
    my $db = youtube_utils::_get_db();

    my $youtube_videos_raw_xml = $db->query( " select * from youtube_videos_raw_xml " )->hashes();

    my $stories_processed = 0;
    my $total_stories   = scalar ( @$youtube_videos_raw_xml );

    foreach my $youtube_video_raw_xml ( @$youtube_videos_raw_xml )
    {
        my $full_xml_string = $youtube_video_raw_xml->{ full_xml_string };
	
	my $dom = XML::LibXML->load_xml( string => $full_xml_string );

	my $entry = $dom->documentElement();

	my $hash = youtube_utils::_get_data_hash_from_youtube_video_entry( $entry );

	#say Dumper ( $hash );

	 youtube_utils::_get_video_record( $hash );
    }
}

sub main
{
    my $author = $ARGV[ 0 ];

    my $lines = 0;

    my $authors_found     = 0;
    my $authors_not_found = 0;

    my $dead_authors = 0;
    my $living_authors;


    #look_up_at_google_talks(' ' );
    #look_up_ted_talk_author();
    look_up_berkman();

    process_raw_xml();

    #look_up_BookTV();
}

main();
