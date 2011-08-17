#!/usr/bin/perl -w

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

sub get_hash_from_string
{
    my ( $xml_string ) = @_;

    my $dom = XML::LibXML->load_xml( string => $xml_string );

    my $story = $dom->documentElement();
    my $xc    = XML::LibXML::XPathContext->new( $story );


    ## TODO preserve paragraph elements of text and textWithHtml elements.

    my $hash_elements = [
        qw (
          title
          subtitle
          shortTitle
          teaser
          miniTeaser
          slug
          thumbnail.medium
          thumbnail.large
          thumbnail.provider
          toenail
          toenail.medium
          storyDate
          pubDate
          lastModifiedDate
          keywords
          priorityKeywords
          byline.name
          organization.name
          organization.website
          audio.duration
          audio.description
          audio.format.mp3
          audio.format.rm
          audio.format.wm
          correction.correctionTitle
          correction.correctionText
          correction.correctionDate
	  text
          )
    ];

    #<organization orgAbbr="NPR" orgId="1">
    #image
    #image.caption
    #image.link
    #image.producer
    #image.provider
    #image.copyright
    #relatedLink
    #relatedLink.caption
    #relatedLink.link
    #pullQuote
    #pullQuote.person
    #pullQuote.date
    #text
    #text.paragraph
    #textWithHtml
    #textWithHtml.paragraph
    #listText
    #listText.item
    #correction

    #say Dumper( $hash_elements );
    $hash_elements = [ map { $_ =~ s/\./\//g; $_ } @$hash_elements ];

    #say Dumper( $hash_elements );

    my $ret = _get_element_values_as_hash( $xc, $hash_elements );

    my $id = $story->getAttribute( 'id' );

    $ret->{ id } = $id;

    return $ret;

    #say Dumper( $dom );
    #say Dumper( $xc );
}

sub _get_attribute_value_of_xpath_query_if_exists
{
    my ( $xc, $query, $attribute ) = @_;

    my @nodes = $xc->findnodes( $query );

    #say Dumper( [ @nodes ] );
    my $node = pop @nodes;

    if ( !defined( $node ) )
    {
        return;
    }

    return _get_attribute_value_of_xpath_query( $xc, $query, $attribute );
}

sub _get_text_value_of_xpath_query_if_exists
{
    my ( $xc, $query, $attribute ) = @_;

    my @nodes = $xc->findnodes( $query );

    #say Dumper( [ @nodes ] );
    my $node = pop @nodes;

    if ( !defined( $node ) )
    {
        return;
    }

    return _get_text_value_of_xpath_query( $xc, $query );
}

sub _get_text_value_of_xpath_query
{
    my ( $xc, $query ) = @_;

    #say "Query $query";
    my @nodes = $xc->findnodes( $query );

    #say Dumper( [ @nodes ] );
    my $node = pop @nodes;

    return $node->textContent();
}

sub _get_element_values_as_hash
{
    my ( $xc, $element_list ) = @_;

    my $ret = {};
    foreach my $element_name ( @$element_list )
    {
        my $query = ".//$element_name";
        my $value = _get_text_value_of_xpath_query_if_exists( $xc, $query );

        $element_name =~ s/\//_/g;
        $ret->{ $element_name } = $value;
    }

    return $ret;
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

sub main
{
    my $key = $ARGV[ 0 ];

    my $lines = 0;

    my $dbh = _get_db();

    my $npr_stories_xml = $dbh->query( " select * from npr_items_raw " )->hashes();

    my $stories_processed = 0;
    my $total_stories   = scalar ( @$npr_stories_xml );

    foreach my $npr_story_xml ( @$npr_stories_xml )
    {

        #say Dumper( $npr_story_xml );

        #exit;
        #say STDERR Dumper([keys %{$npr_story_xml} ] );

        my $xml_string = $npr_story_xml->{ full_xml_string };

        #say $xml_string;

        #exit;

        my $hash = get_hash_from_string( $xml_string );

        #say STDERR Dumper( $hash );

        #map { say "$_ text ," } sort (keys %{ $hash });

        #exit;

	$dbh->query( ' DELETE from npr_items_processed where id = ? ', $hash->{id} );

        $dbh->insert( 'npr_items_processed', $hash );

	say "INSERTED";

	$stories_processed++;

	say "Processed $stories_processed out of $total_stories";

	#exit;
    }

}

main();
