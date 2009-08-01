#!/usr/bin/perl
#
# A simple web statistics script which processes Apache log files and
# outputs a short Markdown-formatted list containing various summary
# statistics.
#
# Usage: perl stats.pl /var/log/apache/access.log > stats.text
#
# Copyright (C) 2008-2009 Jason Blevins
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

use warnings;
use strict;

#---------------------------------------------------
# Configuration

my $baseurl = 'http://jblevins.org';
my $limit = 3;

my $blocked_refs = '^(-|jblevins.org|jblevins.localhost|esnips\.com)$';
my $ignore_paths = join '|',
  qw(^/css/ ^/opensearch.xml ^/sitemap.xml ^/feeds ^/id ^/favicon.ico
     \.jpg$ \.png$ \.svg$ ^/robots.txt ^/accum ^/adsense.html);
my $ignore_ua = join '|',
  qw(slurp Slurp Spider spider Bot bot crawler Wget);

my %link = (
    'google.com'          => 'http://www.google.com/',
    'yahoo.com'           => 'http://www.yahoo.com/',
    'duke.edu'            => 'http://www.duke.edu/',
    'ubuntuforums.org'    => 'http://www.ubuntuforums.org/',
    'reddit.com'          => 'http://www.reddit.com/',
    'delicious.com'       => 'http://delicious.com/',
    'del.icio.us'         => 'http://delicious.com/',
    'live.com'            => 'http://www.live.com/',
    'bing.com'            => 'http://www.bing.com/',
    'wikipedia.org'       => 'http://en.wikipedia.org/',
    'fsdaily.com'         => 'http://www.fsdaily.com/',
);
#---------------------------------------------------

my %escape = (
    '<' => '&lt;',
    '>' => '&gt;',
    '&' => '&amp;',
    '"' => '&quot;'
);
my $escape_re = join '|' => keys %escape;

# Combined format log regular expressions.
my $log_re = qr/^(\S+) (\S+) (\S+) \[([^\]\[]+)\] \"([^"]*)\" (\S+) (\S+) \"?([^"]*)\"? \"([^"]*)\"/;
my $time_re = qr#^(\d{2})/(\w{3})/(\d{4}):(\d{2}):(\d{2}):(\d{2}) ([+-])(\d{2})(\d{2})$#;

my ($page_hits, $feed_hits, $bytes, %referrer, %path, %os, %browser,
    %ip, %date, %reader);

$bytes = 0;
$page_hits = 0;
$feed_hits = 0;

foreach my $file (@ARGV) {
    open LOG, "< $file";

    while (defined(my $line = <LOG>)) {
        my ($ip, $rfc931, $user, $time, $req, $code, $sz, $ref, $ua) = $line =~ $log_re;
        my ($mode, $path, $proto) = split(' ', $req);

        # Bytes transferred
        $bytes = $bytes + $sz unless $sz =~ '-';

        next if $code =~ '206|301|404|410';
        next if $path =~ $ignore_paths;
        next if $ua =~ $ignore_ua;

        # Hits
        if ($path =~ '^/index.atom|^/index.rss|\.cmt$') {
            $feed_hits++;
            $reader{$ip} = 1;
        } else {
            $page_hits++;
            $path{$path}++;
        }

        # Referrers
        my $ref_dom = $ref;
        $ref_dom =~ s#http://(?:www\.)?([^\/]+).*#$1#;

        $ref_dom =~ s#^(.*\.)?google\..*$#google.com#;         # Google
        $ref_dom =~ s#^(.*\.)?yahoo\.com$#yahoo.com#;          # Yahoo
        $ref_dom =~ s#^(.*\.)?live\.com$#live.com#;            # Live
        $ref_dom =~ s#^(.*\.)?msn\.com$#msn.com#;              # MSN
        $ref_dom =~ s#^(.*\.)?wikipedia\.org$#wikipedia.org#;  # Wikipedia
        $ref_dom =~ s#^(.*\.)?reddit\.com$#reddit.com#;        # Reddit
        $referrer{$ref_dom}++ unless ($ref_dom =~ $blocked_refs);

        # Visitors (only count unique IP addresses)
        next if defined($ip{$ip});
        $ip{$ip} = 1;

        # Browsers
        if ($ua =~ '[Ff]irefox|Ice[Ww]easel|BonEcho|Minefield|GranParadiso|Shiretoko|IceCat') {
            $browser{'Firefox'}++;
        } elsif ($ua =~ 'MSIE') {
            $browser{'Internet Explorer'}++;
#        } elsif ($ua =~ 'Opera') {
#            $browser{'Opera'}++;
        } elsif ($ua =~ 'Chrome') {
            $browser{'Chrome'}++;
        } elsif ($ua =~ 'Safari') {
            $browser{'Safari'}++;
#         } elsif ($ua =~ 'Konqueror') {
#             $browser{'Konqueror'}++;
#         } elsif ($ua =~ 'Sea[Mm]onkey|Ice[Aa]pe') {
#             $browser{'SeaMonkey'}++;
#         } elsif ($ua =~ 'Epiphany') {
#             $browser{'Epiphany'}++;
#         } elsif ($ua =~ 'Galeon') {
#             $browser{'Galeon'}++;
#         } elsif ($ua =~ 'Netscape') {
#             $browser{'Netscape'}++;
#         } elsif ($ua =~ 'Links|Elinks') {
#             $browser{'Links'}++;
#         } elsif ($ua =~ 'Lynx') {
#             $browser{'Lynx'}++;
#         } elsif ($ua =~ 'w3m') {
#             $browser{'W3M'}++;
#         } else {
#             $browser{'Other'}++;
#             warn "OTHER BROWSER: $ua\n";
        }

        # Operating System
        if ($ua =~ 'Linux') {
            $os{'Linux'}++;
        } elsif ($ua =~ 'Mac OS') {
            $os{'Mac OS'}++;
        } elsif ($ua =~ 'Windows') {
            $os{'Windows'}++;
#         } elsif ($ua =~ 'SunOS') {
#             $os{'Solaris'}++;
#         } elsif ($ua =~ 'FreeBSD') {
#             $os{'FreeBSD'}++;
#         } elsif ($ua =~ 'NetBSD') {
#             $os{'NetBSD'}++;
#         } elsif ($ua =~ 'OpenBSD') {
#             $os{'OpenBSD'}++;
#         } else {
#             $os{'Other'}++;
#            warn "OTHER OS: $ua\n";
        }
    }
    close LOG;
}

# Aggregate counts
my $mb = int($bytes / (1024 * 1024));
my $num_referrers = scalar keys %referrer;
my $num_visitors = scalar keys %ip;
my $num_readers = scalar keys %reader;

# Sort results
my @browser_sort = sort { $browser{$b} <=> $browser{$a} } keys %browser;
my @os_sort = sort { $os{$b} <=> $os{$a} } keys %os;
my @path_sort = sort { $path{$b} <=> $path{$a} } keys %path;
my @ref_sort = sort { $referrer{$b} <=> $referrer{$a} } keys %referrer;

# Limit results
@ref_sort = @ref_sort[0..$limit-1];
@path_sort = @path_sort[0..$limit-1];

# Format results
my @browser_list = 
  map("    " . linkify($_) . " (" . share($browser{$_}, $num_visitors) . ")", @browser_sort);
my @os_list = 
  map("    " . linkify($_) . " (" . share($os{$_}, $num_visitors) . ")", @os_sort);
my @path_list =
  map("    " . linkify($_) . " (" . share($path{$_}, $page_hits) . ")", @path_sort);
my @ref_list =
  map("    " . linkify($_) . " (" . share($referrer{$_}, $page_hits) . ")", @ref_sort);

# Report
print "  * Page loads: "         . commify($page_hits)          . "\n";
print "  * Unique visitors: "    . commify($num_visitors)       . "\n";
print "  * Unique referrers: "   . commify($num_referrers)      . "\n";
print "  * Feed hits: "          . commify($feed_hits)          . "\n";
print "  * Unique subscribers: " . commify($num_readers)        . "\n";
print "  * Bandwidth: "          . commify($mb) . " MB"         . "\n";
print "  * Browsers:\n"          . join(",\n", @browser_list)   . ".\n";
print "  * Operating systems:\n" . join(",\n", @os_list)        . ".\n";
print "  * Popular pages:\n"     . join(",\n", @path_list)      . ".\n";
print "  * Top referrers:\n"     . join(",\n", @ref_list)       . ".\n";

sub commify {
    local $_  = shift;
    1 while s/^([-+]?\d+)(\d{3})/$1,$2/;
    return $_;
}

sub escape {
    local $_ = shift;
    $_ =~ s/($escape_re)/$escape{$1}/g;
    return $_;
}

sub share {
    my $count = shift;
    my $total = shift;
    return sprintf("%.2f", 100 * $count / $total) . "%";
}

sub linkify {
    local $_ = shift;
    if (m!^/!) {
        # Internal link
        $_ = "[$_]($baseurl$_)";
    } elsif (defined $link{$_}) {
        # Safe referrer
        $_ = "[$_]($link{$_})";
    } elsif (not m!\.(com|edu|net|org|us)$!) {
        # Wikipedia
        my $page = $_;
        $page =~ s/ /_/g;
        $_ = "[$_](http://en.wikipedia.org/wiki/$page)";
    }
    return $_;
}
