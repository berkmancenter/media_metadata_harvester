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
    my ($xml_string) = @_;

     my $dom = XML::LibXML->load_xml( string => $xml_string );

    my $story =  $dom->documentElement();
    my $xc = XML::LibXML::XPathContext->new( $story );

    my $ret = _get_element_values_as_hash( $xc, [ qw ( title subtitle shortTitle teaser miniTeaser slug storyDate pubDate lastModifiedDate keywords priorityKeywords ) ] );

    my $id = $story->getAttribute( 'id' );

    $ret->{ id } = $id;

    return $ret;

    #say Dumper( $dom );
    #say Dumper( $xc );
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
       my $value = _get_text_value_of_xpath_query ( $xc, $query );

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

    my $npr_stories_xml = $dbh->query(" select * from npr_items_raw ")->hashes();

    foreach my $npr_story_xml (@$npr_stories_xml)
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

        $dbh->insert( 'npr_items_processed', $hash );
    }

}

main();
