#!/usr/bin/perl

use strict;
use warnings;

use HTML::TreeBuilder::XPath;
use Test::More tests => 8;

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

{ my $t=  HTML::TreeBuilder->new;
  $t->store_comments( 1);
  $t->parse( '<html><head></head><body><!-- my comment --><p>not a comment</p><!-- more comment --></body></html>');
  is( $t->findvalue( '/html/body/comment()'), ' my comment  more comment ', 'comment value');
}

# test bug #90164: as_XML_indented omits contents of script tag
# the bug affects also the style, xmp, listing and plaintext tags (%HTML::Tagset::isCDATA_Parent).
{
my $html='<script>script content</script>';
my $tree  = HTML::TreeBuilder->new_from_content($html);
my $tree_indent = HTML::TreeBuilder::XPath->new_from_content($tree->as_XML_indented);
like($tree_indent->findvalue('/html/head/script/text()'), qr/^\s*script content\s*$/, "bug #90164");
$tree->delete;
$tree_indent->delete;
}
