#!/usr/bin/perl

use strict;
use warnings;

use HTML::TreeBuilder::XPath;
use Test::More tests => 6;

use utf8;

my %numerical_escapes = ( '&' => '&#38;', '<' =>  '&#60;', '>' => '&#62;', 'é' => '&#233;');
my %minimal_escapes   = ( '&' => '&amp;', '>' =>  '&gt;', '<' => '&lt;', );

my $text= '& & < > & été été été';

(my $as_xml= $text)   =~ s{(.)}{$minimal_escapes{$1} || $1}eg;
#(my $as_xml_default= $text) =~ s{(.)}{$numerical_escapes{$1} || $1}eg;
#(my $as_xml= $text) =~ s{(.)}{$numerical_escapes{$1} || $1}eg;

my $html=qq{<html>
             <head></head>
             <body>
               <p>&amp; &amp; &lt; &gt; &amp; été été été</p>
               <p>&amp; &amp &lt &gt &amp &eacute;t&eacute &#xe9;t&#xe9 &#233;t&#233</p>
             </body>
           };

my $tree  = HTML::TreeBuilder->new_from_content( $html);

foreach my $p ($tree->findnodes("//p"))
  { is( $p->as_XML_indented, "<p>$as_xml</p>\n", "p as_XML_indented");
    is( $p->as_XML_compact, "<p>$as_xml</p>", "p as_XML_compact");
    is( ($p->findnodes( './node()[1]'))[0]->as_XML_indented, $as_xml, "text node as_XML()");
  }
