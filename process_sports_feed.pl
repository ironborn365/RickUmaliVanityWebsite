#!perl
#
# process_sports_feed.pl
#
# Reads an XML file containing Rick on Sports "feed" from FeedBurner. The
# feed is in RSS. This program dumps to STDOUT. The program reads the
# template file sports_start.tmpl
#
# Usage:
#
# perl process_sports_feed.pl feed-RickOnSports.xml > sports.tmpl
#
# 2007-12-01 - Original
#
# 2007-12-05 - Modified code to handle pretty-printing of date
#
# 2007-12-07 - Modified code to use Template Toolkit
#
# 2010-10-30 - Modified code to handle Rowdy's first <p> in <description> tag.
#
use strict;

use XML::Simple;
use Data::Dumper;
use Getopt::Long;
use HTML::TokeParser;
use Template;

my $opt_debug = 0;
my $opt_dump = 0;

GetOptions (
	'debug' => \$opt_debug,
	'dump' => \$opt_dump,
	); 

if (scalar(@ARGV) != 1) {
	exit 1;
}

my $feed_xml_file = $ARGV[0];

my $rss_feed = XMLin($feed_xml_file);

print STDERR Dumper($rss_feed) if $opt_dump;

my $item_count = 0;
my $channel_hash;

# Walk through each "element" of the RSS feed. When you see the "entry" element,
# save it away in a hash ref
foreach my $elem (keys %{$rss_feed}) {
	if ($elem eq "channel") {
		$channel_hash = $rss_feed->{$elem};
	}
}

# The "channel" hash ref contains an item array. Walk through
# each "item", and build a structure that will hold the template's
# variables.
my @entry_array = ();

if ($channel_hash->{item} == undef) {
	# Added this code to detect degenerate feeds. The resulting 
	# file will be 0, but at least now during the debugging, you'll
	# know why! If you're in here, it's because the feed doesn't have
	# any RSS "items" in it. It's EMPTY! Check the raw feed itself, 
	# using the "-dump" switch.
	print "No item array in the channel! Bad feed!";
	exit 1;
}
my @item_array = @{$channel_hash->{item}};
foreach my $item (@item_array) {
	last if $item_count >= 10;
	print "$item_count: $item\n" if $opt_debug;

	my $published_date = get_published_date($item);
	my $title = get_title($item);
	my $link = get_url_link($item);
	my $text = get_truncated_text($item, 160);

	# This builds an array of anonymous HASHes containing the data
	# that will be shown in the template
	push @entry_array, { 
		published_date => $published_date,
		title => $title, 
		url => $link, 
		text => $text, 
	};

	$item_count++;
}

my $vars = {
	current_time_stamp => localtime() . "",
	entries => \@entry_array,
};
my $tt = Template->new({
	INTERPOLATE => 1,
#	POST_CHOMP => 1,
}) || die "$Template::ERROR\n";

$tt->process('sports_start.tmpl', $vars)
	|| die $tt->error(), "\n";

sub get_published_date () {
	my $entry = shift;
	print "\tPublished: " . $entry->{"pubDate"} . "\n" if $opt_debug;

	# The feed contains a timestamp formatted like this:
	#
	# Wed, 22 Jun 2016 21:15:22 -0400

	# Break apart the timestamp, and reformat it
	my ($unused, $day, $month, $year, $time, $zone) = split(' ', $entry->{"pubDate"});

	# The month_full HASH translates from the abbreviation to the full
	# month name
	my %month_full = (
		Jan => "January",
		Feb => "February",
		Mar => "March",
		Apr => "April",
		May => "May",
		Jun => "June",
		Jul => "July",
		Aug => "August",
		Sep => "September",
		Oct => "October",
		Nov => "November",
		Dec => "December",
	);

	$day =~ s/^0//; # Strip out any leading zeros
	return($month_full{$month} . " $day, $year");
}

sub get_url_link () {
	my $entry = shift;
	print "\tLink: " . $entry->{"link"} . "\n" if $opt_debug;
	return($entry->{"link"});
}

sub get_title () {
	my $entry = shift;
	print "\tTitle: " . $entry->{"title"} . "\n" if $opt_debug;
	return($entry->{"title"});
}

sub get_text() {
	my $entry = shift;

	print "\tText: " . $entry->{"description"} . "\n" if $opt_debug;
	return($entry->{"description"});
}

sub get_truncated_text() {
	my $entry = shift;
	my $min_chars = shift;

	my $text_stream = HTML::TokeParser->new(\$entry->{"description"});

	my $text = $text_stream->get_phrase();
	print "\tTEXT AFTER GET $text\n" if $opt_debug;

	if (length($text) < $min_chars) {
		print "\tTEXT: $text\n" if $opt_debug;
		return($text);
	} else {

		my $pos = 0;
		while ($pos < $min_chars) {
			$pos = index($text, " ", $pos+1);
			if ($pos == -1)	{
				# Bail out if index() returns -1. This means
				# that no spaces exist before $min_chars. This 
				# bail out code was added because of a boundary 
				# condition that caused this while() loop to 
				# run infinitely the week of 10/13/2008. NetAtlantic
				# shutdown rickumali.com because of this. See
				# Notebook files 20081017 and 20081018
				last;
			}
		}

		print "\tTEXT: " . substr($text,0,$pos) . " ..." . "\n"  if $opt_debug;
		return(substr($text,0,$pos) . "...");
	}
}
