package youtube_utils;

use Feed::Find;
use Data::Dumper;
use Encode;
use LWP::UserAgent;
use XML::LibXML;
use Carp;
#use XML::LibXML::Enhanced;

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


sub _get_text_value_of_xpath_query
{
    my ( $xc, $query ) = @_;

    my @nodes = $xc->findnodes( $query );

    #say Dumper( [ @nodes ] );
    my $node = pop @nodes;

    return $node->textContent();
}

sub _get_attribute_value_of_xpath_query
{
    my ( $xc, $query, $attribute ) = @_;

    my @nodes = $xc->findnodes( $query );

    #say Dumper( [ @nodes ] );
    my $node = pop @nodes;

    #say STDERR '_get_attribute_value_of_xpath_query';
    #say STDERR $attribute;
    #say STDERR $node->toStringC14N();

    return $node->getAttribute( $attribute );
}

sub _get_attribute_value_of_xpath_query_if_exists
{
    my ( $xc, $query, $attribute ) = @_;

    my @nodes = $xc->findnodes( $query );

    #say Dumper( [ @nodes ] );
    my $node = pop @nodes;

    if ( ! defined( $node ) )
    {
       return;
    }

    return _get_attribute_value_of_xpath_query ( $xc, $query, $attribute );
}

sub _get_data_hash_from_youtube_video_entry
{
    my ( $entry ) = @_;

    #say "starting: _get_data_hash_from_youtube_video_entry";

    #say Dumper( $entry );

    my $xc = XML::LibXML::XPathContext->new( $entry );

    $xc->setContextNode( $entry );
    $xc->registerNs( 'a', 'http://www.w3.org/2005/Atom' );

    #say Dumper($entry->toHash( 1) );

    my $id = _get_text_value_of_xpath_query( $xc, './/a:id' );

    my $full_string = $entry->toStringC14N();

    #say $full_string;

    my $title = _get_text_value_of_xpath_query( $xc, './a:title' );

    my $description = _get_text_value_of_xpath_query( $xc, './a:content' );

    my $channel = _get_text_value_of_xpath_query( $xc, './a:author/a:name' );

    my $duration_seconds  =  _get_attribute_value_of_xpath_query( $xc, './media:group/yt:duration', 'seconds' );
    my $media_keywords  =  _get_text_value_of_xpath_query( $xc, './media:group/media:keywords' );

    #say $media_keywords;
    #exit;

    my $rating_average = _get_attribute_value_of_xpath_query_if_exists( $xc, './gd:rating', 'average' );
    my $rating_max     = _get_attribute_value_of_xpath_query_if_exists( $xc, './gd:rating', 'max' );
    my $rating_min     = _get_attribute_value_of_xpath_query_if_exists( $xc, './gd:rating', 'min' );

    my $rating_numRaters     = _get_attribute_value_of_xpath_query_if_exists( $xc, './gd:rating', 'numRaters' );

    #say "id------------------------";

    #say $id;

    my $ret = {
        id          => $id,
        full_string => $full_string,
        title       => $title,
        description => $description,
	channel     => $channel,
	duration_seconds   => $duration_seconds,
        keywords        => $media_keywords,
	rating_average => $rating_average,
	rating_max => $rating_max,
	rating_min => $rating_min,
	rating_numRaters => $rating_numRaters,
    };

    #say Dumper( $ret );

    #say "ending:_get_data_hash_from_youtube_video_entry";

    return $ret;
}

sub _get_db
{
    my $dbargs = {
        AutoCommit => 1,
        RaiseError => 1,
        PrintError => 1,
    };

    my $dbh = DBIx::Simple->connect( DBI->connect( "dbi:SQLite:dbname=yt.db", "", "", $dbargs ) );

    return $dbh;
}


sub _store_video_in_db
{
    my ( $hash ) = @_;

    #say "storing video in the db";
    my $dbh = _get_db();

    $dbh->insert( 'youtube_videos', $hash );
}

sub _get_video_record
{
    my ( $hash ) = @_;

    my $dbh = _get_db();

    #say "_get_video_record: id: " . $hash->{ id };

    my $ret = $dbh->query( 'select * from youtube_videos where id = ? ', $hash->{ id } )->hash;

    if ( !$ret )
    {
        _store_video_in_db( $hash );
	$ret = $dbh->query( 'select * from youtube_videos where id = ? ', $hash->{ id } )->hash;
	die unless $ret;
    }

    #say "done _get_video_record: id: " . $hash->{ id };
    return $ret;
}

sub store_raw_xml_for_video
{
    my ( $entry ) = @_;

    my $xc = XML::LibXML::XPathContext->new( $entry );
    my  $full_xml_string = $entry->toStringC14N();
    
    $xc->setContextNode( $entry );
    $xc->registerNs( 'a', 'http://www.w3.org/2005/Atom' );
    
    #say Dumper($entry->toHash( 1) );
    
    my $id = _get_text_value_of_xpath_query( $xc, './/a:id' );
    
    my $db = _get_db();
    
    my $raw_xml_hash = { id => $id, full_xml_string => $full_xml_string };
    
    $db->query(" DELETE FROM youtube_videos_raw_xml where id = ? ", $id);
    $db->insert( 'youtube_videos_raw_xml', $raw_xml_hash );

    return;
}

1;
