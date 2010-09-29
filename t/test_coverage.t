#!/usr/bin/perl

use strict;
use warnings;

use HTML::TreeBuilder::XPath;
use Test::More tests => 9;

use utf8;

{ my $html=qq{<html>
               <head></head>
               <body xmlns:foo="http://foo.org">
                 <!-- comment 1 -->
                 <p>p1</p>
                 <p>p2</p>
                 <!-- comment 2 -->
               </body>
             };

  my $tree  = HTML::TreeBuilder->new;
  $tree->store_comments(1);
  $tree->parse_content( $html);

  is( $tree->findvalue( '/html/body/*[local_name()="p"][2]'), 'p2', 'local_name');
  is( $tree->findnodes_as_string( '//p'), "<p>p1</p>\n<p>p2</p>\n", 'findnodes_as_string');
}

{ my $html=qq{<html><head></head><body><p>foo</p></body></html>};
  my $tree= HTML::TreeBuilder->new_from_content( $html);
  is( $tree->as_XML_compact, $html, 'as_XML_compact');
  is( $tree->as_XML_indented, qq{<html>\n  <head></head>\n  <body>\n    <p>foo</p>\n  </body>\n</html>\n}, 'as_XML_indented');
}

{ my $html=qq{<html><head></head><body><img height="5" width="6" id="i1" /><img height="7" width="6" id="i2" /></body></html>};
  my $tree= HTML::TreeBuilder->new_from_content( $html);
  is( $tree->findvalue( '//img[@* = "7"]/@id'), 'i2', '//img[@* = "7"]/@id');
  is( $tree->findvalue( '//img[@height < @width]/@id'), 'i1', '//img[@height < @width]/@id');
  is( $tree->findvalue( '//img[@height < @width]/@id'), 'i1', '//img[@height < @width]/@id');
  is( $tree->findvalue( '//img[@height < @width]/@id[1]'), 'i1', '//img[@height < @width]/@id[1]');
  is( $tree->findvalue( '//img[preceding-sibling::img]/@id'), 'i2', '//img[preceding-sibling::img]/@id');
}

