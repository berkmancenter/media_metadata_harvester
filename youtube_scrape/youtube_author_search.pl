#!/usr/bin/perl -w

use Feed::Find;
use Data::Dumper;
use Encode;
use LWP::UserAgent;
use XML::LibXML;

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

sub look_up_youtube_author_talk
{
    my ( $author, $channel ) = @_;

    my $base_url = "http://gdata.youtube.com/feeds/api/users/$channel/uploads";

    return _youtube_lookup( $author, $base_url );
}

sub look_up_youtube_global
{
    my ( $author ) = @_;

    my $youtube_global_search_api = 'https://gdata.youtube.com/feeds/api/videos';
    return _youtube_lookup( $author, $youtube_global_search_api );
}

my $channel_author_counts = {};

sub _get_text_value_of_xpath_query
{
    my ( $xc, $query ) = @_;

    my @nodes = $xc->findnodes( $query );

    say Dumper( [ @nodes] );
    my $node = pop @nodes;

    return $node->textContent();
}

 sub _get_data_hash_from_youtube_video_entry
 {
     my ( $entry ) = @_;

     say Dumper( $entry );

     my $xc = XML::LibXML::XPathContext->new( $entry );

     $xc->setContextNode( $entry );
     $xc->registerNs( 'a', 'http://www.w3.org/2005/Atom' );

     #say Dumper($entry->toHash( 1) );

     my $id = _get_text_value_of_xpath_query( $xc, './/a:id' );

     my $full_string = $entry->toStringC14N();

     my $title = _get_text_value_of_xpath_query( $xc, './a:title' );

     my $description = _get_text_value_of_xpath_query( $xc, './a:content' );

     say "id------------------------";

     #say $id;

     my $ret = {
		id          => $id,
		full_string => $full_string,
		title       => $title,
		description => $description
      };

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
   my ($hash ) = @_;

   my $dbh = _get_db();

   $dbh->insert( 'youtube_videos', $hash );
}

sub _get_video_record
{
    my ( $hash ) = @_;

    my $dbh = _get_db();

    say "_get_video_record: id: " . $hash->{ id };

    if (! $dbh->query( 'select * from youtube_videos where id = ? ', $hash->{id} ) )
    {
       _store_video_in_db( $hash );
    }

    my $ret = $dbh->query( 'select * from youtube_videos where id = ? ', $hash->{id} )->hash;

    say Dumper( $ret );

    #exit;

    say "done _get_video_record: id: " . $hash->{ id };
    return $ret;
}

sub _youtube_lookup
{
    my ( $author, $base_url ) = @_;

    my $uri = URI->new( $base_url );

    $uri->query_form( { q => '"' . $author . '"', prettyprint => 'true' } );

    # Create a request
    my $req = HTTP::Request->new( GET => $uri );

    my $ua = LWP::UserAgent->new;

    # Pass request to the user agent and get a response back
    my $res = $ua->request( $req );

    # Check the outcome of the response
    if ( $res->is_success )
    {

        #say 'URL final = ' . $res->request->uri;
        my $content = $res->content;

        my $dom = XML::LibXML->load_xml( string => $content );

        my $xc = XML::LibXML::XPathContext->new( $dom );

        #'http://a9.com/-/spec/opensearchrss/1.0/

        my @nodes = $xc->findnodes( '//openSearch:totalResults' );

        $xc->registerNs( 'a', 'http://www.w3.org/2005/Atom' );
        my $totalResults_node = $nodes[ 0 ];

        die unless $totalResults_node;

        my $num_results = $totalResults_node->textContent();

        #say "$num_results nodes for author: $author in $channel";

        if ( $num_results )
        {
            #say $content;

            #exit;

            #my $xc = XML::LibXML::XPathContext->new( $dom );

            my @video_authors = $xc->findnodes( '//a:entry/a:author/a:name' );

            #say Dumper( [ @video_authors ] );

            my $names = [ map { $_->textContent() } @video_authors ];

            $names = [ uniq( @{ $names } ) ];

            foreach my $chan_name ( @{ $names } )
            {
                $channel_author_counts->{ $chan_name } //= 0;
                $channel_author_counts->{ $chan_name }++;
            }

            if ( any { $_ eq 'TEDtalksDirector' } @$names )
            {
                #say "author $author found in TEDtalksDirector";
            }

            my @entries = $xc->findnodes( '//a:entry' );

	    foreach my $entry ( @entries )
	    {
	        #my $hash = _get_data_hash_from_youtube_video_entry( $entry );

		#say Dumper ( $hash );

		#_get_video_record( $hash );
	    }

            #	  say Dumper($names);
            #	  exit;
            return [ @entries ];

        }
        else
        {
            return 0;
        }

        #<openSearch:totalResults>
    }

    return;
}

sub look_up_ted_talk_author
{
    my ( $author ) = @_;

    return look_up_youtube_author_talk( $author, 'TEDtalksDirector' );
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

    my $results = $dbh->query( " SELECT * from books where author = ? and title = ?  limit 1",  $author, $title );

    say Dumper ( $results );

    my $ret = $results->hashes;

    say Dumper( $ret );

    say Dumper(  scalar( @ $ret ) );

    if ( ! scalar( @ $ret ) )
    {
       $dbh->query( "INSERT INTO books (author, title) VALUES (?, ? ) " , $author, $title );
       $results = $dbh->query( " SELECT * from books where author = ? and title = ?  limit 1",  $author, $title );
    }

    return $results->hash;
}

sub store_book_videos
{
    my ( $book_rec, $video_entries ) = @_;

    say STDERR "store_book_videos";

    foreach my $video_entry (@ $video_entries ) 
    {

        say STDERR "Processing video entry ";
        my $hash = _get_data_hash_from_youtube_video_entry( $video_entry );

	#say Dumper ( $hash );

	_get_video_record( $hash );
    }
}

sub look_up_book_videos
{
    my ( $title, $author ) = @_;

    say STDERR "look_up_book_videos";
    #exit;
    my $book_rec = get_book_db_record( $title, $author );

    my $videos = look_up_ted_talk_author ( $author );

    say STDERR "Videos storage ";
    store_book_videos ( $book_rec, $videos );

    say STDERR "Done video storage ";


    say STDERR "exiting look_up_book_videos";

    exit;
}

sub main
{
    my $author = $ARGV[ 0 ];

    my $lines = 0;

    my $authors_found     = 0;
    my $authors_not_found = 0;

    my $dead_authors = 0;
    my $living_authors;

    while ( my $line = <> )
    {
        my ( $title, $author_field ) = split "\t", $line;

        #say "Title: '$title' Author: '$author_field'";

        $lines++;

        next if ( !$author_field );

        chop( $author_field );

        my ( $author_last_name, $author_first_name, $author_life_time ) = split /,\s*/, $author_field;

        $author_first_name //= '';
        $author_first_name =~ s/\(.*\)//;

        if ( defined( $author_life_time ) )
        {
            my ( $birth_year, $death_year ) = split '-', $author_life_time;
            if ( defined( $death_year ) )
            {

                #say "Death author: $author_field";
                $dead_authors++;
                next;
            }
        }

        $living_authors++;

        #say "Living author: $author_field";

        #last if $lines >= 10;

        #next;

        my $author = "$author_first_name $author_last_name";

        #say "'$author'";

	look_up_book_videos( $title, $author );
	
	next;

        my $has_talk = look_up_ted_talk_author( $author );

        if ( $has_talk )
        {
            $authors_found++;
            say "Found talk for author: $author\n";
        }
        else
        {
            $authors_not_found++;
        }
    }

    my $channels = [ keys %{ $channel_author_counts } ];

    $channels = [ sort { $channel_author_counts->{ $a } <=> $channel_author_counts->{ $b } } @{ $channels } ];

    $channels = [ reverse @$channels ];

    foreach my $channel ( @{ $channels } )
    {
        say "$channel - $channel_author_counts->{ $channel } ";
    }

    say "Records: $lines";
    say "dead authors: $dead_authors";
    say "living authors: $living_authors";
    say "Found $authors_found";
    say "Couldn't find $authors_not_found";

    #$author = 'Nathan Myhrvold';
}

main();
