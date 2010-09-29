package HTML::TreeBuilder::XPath;


use strict;
use warnings;

use vars qw($VERSION);

$VERSION = '0.10';

my %CHAR2DEFAULT_ENT= ( '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quote;');
my %NUM2DEFAULT_ENT= ( '38' => 'amp', '60' => 'lt', '62' => 'gt', '"' => '&quote;');

package HTML::TreeBuilder::XPath;

use base( 'HTML::TreeBuilder');


package HTML::TreeBuilder::XPath::Node;

sub isElementNode   { 0 }
sub isAttributeNode { 0 }
sub isNamespaceNode { 0 }
sub isTextNode      { 0 }
sub isProcessingInstructionNode { 0 }
sub isPINode        { 0 }
sub isCommentNode   { 0 }

sub getChildNodes { return wantarray ? () : []; }
sub getFirstChild { return undef; }
sub getLastChild { return undef; }

sub getElementById 
  { my ($self, $id) = @_;
    return scalar $self->look_down( id => $id);
  }

sub to_number { return XML::XPathEngine::Number->new( shift->getValue); }

sub cmp
  { my( $a, $b)=@_;

    # comparison with the root (in $b, or processed in HTML::TreeBuilder::XPath::Root)
    if( $b->isa( 'HTML::TreeBuilder::XPath::Root') ) { return -1; }

    # easy cases
    return  0 if( $a == $b);    
    return  1 if( $a->is_inside($b)); # a starts after b 
    return -1 if( $b->is_inside($a)); # a starts before b

    # lineage does not include the element itself
    my @a_pile= ($a, $a->lineage); 
    my @b_pile= ($b, $b->lineage);
    
    # the 2 elements are not in the same twig
    unless( $a_pile[-1] == $b_pile[-1]) 
      { warn "2 nodes not in the same pile: ", ref( $a), " - ", ref( $b), "\n"; 
        print "a: ", $a->string_value, "\nb: ", $b->string_value, "\n";
        return undef;
      }

    # find the first non common ancestors (they are siblings)
    my $a_anc= pop @a_pile;
    my $b_anc= pop @b_pile;

    while( $a_anc == $b_anc) 
      { $a_anc= pop @a_pile;
        $b_anc= pop @b_pile;
      }

    if( defined( $a_anc->{_rank}) && defined( $b_anc->{_rank}))
      { return $a_anc->{_rank} <=> $b_anc->{_rank}; }
    else
      {
        # from there move left and right and figure out the order
        my( $a_prev, $a_next, $b_prev, $b_next)= ($a_anc, $a_anc, $b_anc, $b_anc);
        while()
          { $a_prev= $a_prev->getPreviousSibling || return -1;
            return  1 if( $a_prev == $b_anc);
            $a_next= $a_next->getNextSibling     || return  1;
            return -1 if( $a_next == $b_anc);
            $b_prev= $b_prev->getPreviousSibling || return  1;
            return -1 if( $b_prev == $a_next);
            $b_next= $b_next->getNextSibling     || return -1;
            return  1 if( $b_next == $a_prev);
          }
      }
  }


# need to modify directly the HTML::Element package, because HTML::TreeBuilder won't let me
# change the class of the nodes it generates
package HTML::Element;
use Scalar::Util qw(weaken);
use vars qw(@ISA);

push @ISA, 'HTML::TreeBuilder::XPath::Node';

use XML::XPathEngine;

{ my $xp;
  sub xp
    { $xp ||=XML::XPathEngine->new();
      return $xp;
    }
}

sub findnodes            { my( $elt, $path)= @_; return xp->findnodes(            $path, $elt); }
sub findnodes_as_string  { my( $elt, $path)= @_; return xp->findnodes_as_string(  $path, $elt); }
sub findnodes_as_strings { my( $elt, $path)= @_; return xp->findnodes_as_strings( $path, $elt); }
sub findvalue            { my( $elt, $path)= @_; return xp->findvalue(            $path, $elt); }
sub exists               { my( $elt, $path)= @_; return xp->exists(               $path, $elt); }
sub find_xpath           { my( $elt, $path)= @_; return xp->find(                 $path, $elt); }
sub matches              { my( $elt, $path)= @_; return xp->matches( $elt, $path, $elt);        }
sub set_namespace        { my $elt= shift; xp->new->set_namespace( @_); }

sub getRootNode
  { my $elt= shift;
    # The parent of root is a HTML::TreeBuilder::XPath::Root
    # that helps getting the tree to mimic a DOM tree
    return $elt->root->getParentNode; # I like this one!
  }

sub getParentNode
  { my $elt= shift;
    return $elt->{_parent} || bless { _root => $elt }, 'HTML::TreeBuilder::XPath::Root';
  }
sub getName             { return shift->tag;   }
sub getNextSibling      { my( $elt)= @_; 
                          my $parent= $elt->{_parent} || return undef;
                          return  $parent->_child_as_object( scalar $elt->right, ($elt->{_rank} || 0) + 1);
                        }
sub getPreviousSibling  { my( $elt)= @_; 
                          my $parent= $elt->{_parent} || return undef;
                          return undef unless $elt->{_rank};
                          return  $parent->_child_as_object( scalar $elt->left, $elt->{_rank} - 1); 
                        }
sub isElementNode       { return ref $_[0] && ($_[0]->{_tag}!~ m{^~}) ? 1 : 0; }
sub isCommentNode       { return ref $_[0] && ($_[0]->{_tag} eq '~comment') ? 1 : 0; }
sub isProcessingInstructionNode { return ref $_[0] && ($_[0]->{_tag} eq '~pi') ? 1 : 0; }
sub isTextNode          { return ref $_[0] ? 0 : 1; }

sub getValue 
  { my $elt= shift;
    if( $elt->isCommentNode) { return $elt->{_text}; }
    return $elt->as_text;
  }
        
sub getChildNodes    
  { my $parent= shift;
    my $rank=0;
    my @children= map { $parent->_child_as_object( $_, $rank++) } $parent->content_list;
    return wantarray ? @children : \@children;
  }

sub getFirstChild
  { my $parent= shift;
    my @content= $parent->content_list;
    if( @content)
      { return $parent->_child_as_object( $content[0], 0); }
    else
      { return undef; }
  }
sub getLastChild
  { my $parent= shift;
    my @content= $parent->content_list;
    if( @content)
      { return $parent->_child_as_object( $content[-1], $#content); }
    else
      { return undef; }
  }

sub getAttributes
  { my $elt= shift;
    my %atts= $elt->all_external_attr;
    my $rank=0;
    my @atts= map { bless( { _name => $_, _value => $atts{$_}, 
                             _elt => $elt, _rank => $rank++, 
                           }, 
                               'HTML::TreeBuilder::XPath::Attribute'
                         )
                  } sort keys %atts;
    return wantarray ? @atts : \@atts;
  }

sub to_number { return XML::XPathEngine::Number->new( $_[0]->as_text); }
sub string_value 
  { my $elt= shift;
    if( $elt->isCommentNode) { return $elt->{_text}; }
    return $elt->as_text;
  };

# called on a parent, with a child as second argument and its rank as third
# returns the child if it is already an element, or
# a new HTML::TreeBuilder::XPath::Text element if it is a plain string
sub _child_as_object
  { my( $elt, $elt_or_text, $rank)= @_;
    return undef unless( defined $elt_or_text);
    if( ! ref $elt_or_text)
      { # $elt_or_text is a string, turn it into a TextNode object
        $elt_or_text= bless { _content => $elt_or_text, _parent => $elt, }, 
                            'HTML::TreeBuilder::XPath::TextNode'
                      ;
      }
    if( ref $rank) { warn "rank is a ", ref( $rank), " elt_or_text is a ", ref( $elt_or_text); } 
    $elt_or_text->{_rank}= $rank; # used for sorting;
    return $elt_or_text;
  }

sub toString { return shift->as_XML_clean( @_); }

# produces better looking XML
{ my( $indent, %return_before_endtag);
  BEGIN 
    { $indent= '  '; 
      %return_before_endtag= map { $_ => 1 } qw(html head body script div table tr form ol ul);
    }
 
  sub as_XML_clean
    { my( $node, $indent_level)= @_;

      my $xml= '';
      my $wrapping_nl= "\n"; 

      if( !defined( $indent_level)) { $indent_level = 0; $wrapping_nl= ''; }
      
      my $name = $node->{'_tag'};
      if( $HTML::Tagset::isKnown{lc $name} && !$HTML::Tagset::isPhraseMarkup{lc $name} && $indent_level > 0) 
        { $xml.= $wrapping_nl . ($indent x $indent_level); }

      if(    $name eq '~literal')     { $xml= _xml_escape_text( $node->{text});                    }
      elsif( $name eq '~declaration') { $xml= '<!' . _xml_escape_text( $node->{text}) . '>';       }
      elsif( $name eq '~pi')          { $xml= '<?' . _xml_escape_text( $node->{text}) . '?>';      }
      elsif( $name eq '~comment')     { $xml= '<--' . _xml_escape_comment( $node->{text}) . '-->'; }
      elsif( $HTML::Tagset::isCDATA_Parent{lc $name})
        { $xml.= $node->_start_tag;
          my $content= $node->{_content} || '';
          if( ref $content eq 'ARRAY' || $content->isa( 'ARRAY'))
            { $xml .= _xml_escape_cdata( join( '', @$content)); }
          if( $return_before_endtag{lc $name}) { $xml.= "\n" . ($indent x $indent_level); }
        }
      else
        { # start tag
          $xml.= $node->_start_tag;
          my $child_indent_level= $HTML::Tagset{lc $name} ? $indent_level : $indent_level+1;
          foreach my $child ($node->content_list) 
            { if( ref $child) { $xml .= $child->as_XML_clean( $child_indent_level); }
              else            { $xml .=  _xml_escape_text( $child); }
            }
          if( $return_before_endtag{lc $name}) { $xml.= "\n" . ($indent x $indent_level); }
        }
      $xml .="</$name>" unless $HTML::Tagset::emptyElement{lc $name};
      if( $indent_level == 0) { $xml .= $wrapping_nl; }
      return $xml;
    }
}


sub _start_tag
  { my( $node)= @_;
    my $name = $node->{'_tag'};
    my $start_tag.= "<$name";
    foreach my $att (sort keys %$node) 
      { next if( (!length $att) ||  ($att=~ m{^_}) || ($att eq '/') );
        $start_tag .= qq{ $att="} . _xml_escape_attribute_value $node->{$att} . qq{"};
      }
    $start_tag.= $HTML::Tagset::emptyElement{lc $name} ? " />" : ">";
    return $start_tag;
  }

sub _indent_level
  { my( $node)= @_;
    my $level= scalar grep { !$HTML::Tagset::isPhraseMarkup{lc $_->{_tag}} } $node->lineage;
    return $level;
  }
   
    
sub _xml_escape_attribute_value
  { my( $text)= @_;
    $text=~ s{([&<>"])}{$CHAR2DEFAULT_ENT{$1}}g; # escape also quote, as it is the attribute separator
    return $text;
  }

sub _xml_escape_text
  { my( $text)= @_;
    $text=~ s{([&<>])}{$CHAR2DEFAULT_ENT{$1}}g;
    return $text;
  }

sub _xml_escape_comment
  { my( $text)= @_;
    $text=~ s{([&<>])}{$CHAR2DEFAULT_ENT{$1}}g;
    $text=~ s{--}{-&#45;}g; # can't have double --'s in XML comments
    return $text;
  }

sub _xml_escape_cdata
  { my( $text)= @_;
    $text=~ s{^\s*\Q<![CDATA[}{}s;
    $text=~ s{\Q]]>\E\s*$}{}s;
    $text=~ s{]]>}{]]&#62;}g; # can't have]]> in CDATA
    $text=  "<![CDATA[$text]]>";
    return $text;
  }


package HTML::TreeBuilder::XPath::TextNode;

use base 'HTML::TreeBuilder::XPath::Node';

sub getParentNode { return shift->{_parent};    }
sub getValue      { return shift->{_content};   }
sub isTextNode    { return 1;                   }
sub getAttributes { return wantarray ? () : []; }

# similar to HTML::Element as_XML
sub as_XML
  { my( $node, $entities)= @_;
    my $content= $node->{_content};
    if( $node->{_parent} && $node->{_parent}->{_tag} eq 'script')
      { $content=~ s{(&\w+;)}{HTML::Entities::decode($1)}eg; }
    else
      { HTML::Element::_xml_escape($content); }
    return $content;
  }

sub as_XML_clean
  { my( $node, $entities)= @_;
    my $content= $node->{_content};
    if( $node->{_parent} && $node->{_parent}->{_tag} eq 'script')
      { $content=~ s{(&\w+;)}{HTML::Entities::decode($1)}eg; }
    else
      { $content= HTML::Element::_xml_escape_text($content); }
    return $content;
  }

sub getPreviousSibling
  { my $self= shift;
    my $rank= $self->{_rank}; 
    #unless( defined $self->{_rank})
    #  { warn "no rank for text node $self->{_content}, parent is $self->{_parent}->{_tag}\n"; }
    my $parent= $self->{_parent};
    return $rank ? $parent->_child_as_object( $parent->{_content}->[$rank-1], $rank-1) : undef;
  }

sub getNextSibling
  { my $self= shift;
    my $rank= $self->{_rank};
    #unless( defined $self->{_rank})
    #  { warn "no rank for text node $self->{_content}, parent is $self->{_parent}->{_tag}\n"; }
    my $parent= $self->{_parent};
    my $next_sibling= $parent->{_content}->[$rank+1];
    return defined( $next_sibling) ? $parent->_child_as_object( $next_sibling, $rank+1) : undef;
  }

sub getRootNode
  { return shift->{_parent}->getRootNode; }

sub string_value { return shift->{_content}; }

# added to provide element-like methods to text nodes, for use by cmp
sub lineage 
  { my( $node)= @_;
    my $parent= $node->{_parent};
    return( $parent, $parent->lineage);
  }

sub is_inside
  { my( $text, $node)= @_;
    return $text->{_parent}->is_inside( $node);
  }

1;


package HTML::TreeBuilder::XPath::Attribute;
use base 'HTML::TreeBuilder::XPath::Node';

sub getParentNode   { return $_[0]->{_elt}; }
sub getValue        { return $_[0]->{_value}; }
sub getName         { return $_[0]->{_name} ; }
sub getLocalName    { (my $name= $_[0]->{_name}) =~ s{^.*:}{}; $name; }
sub string_value    { return $_[0]->{_value}; }
sub to_number       { return XML::XPathEngine::Number->new( $_[0]->{_value}); }
sub isAttributeNode { 1 }
sub toString        { return qq{$_[0]->{_name}="$_[0]->{_value}"}; }

# awfully inefficient, but hopefully this is called only for weird (read test-case) queries
sub getPreviousSibling
  { my $self= shift;
    my $rank= $self->{_rank};
    return undef unless $rank;
    my %atts= $self->{_elt}->all_external_attr;
    my $previous_att_name= (sort keys %atts)[$rank-1]; 
    return bless( { _name => $previous_att_name, 
                             _value => $atts{$previous_att_name}, 
                             _elt => $self->{_elt}, _rank => $rank-1, 
                   }, 'HTML::TreeBuilder::XPath::Attribute'
                );
  }

sub getNextSibling
  { my $self= shift;
    my $rank= $self->{_rank};
    my %atts= $self->{_elt}->all_external_attr;
    my $next_att_name= (sort keys %atts)[$rank+1] || return undef; 
    return bless( { _name => $next_att_name, _value => $atts{$next_att_name}, 
                             _elt => $self->{_elt}, _rank => $rank+1, 
                   }, 'HTML::TreeBuilder::XPath::Attribute'
                );
    
  }



# added to provide element-like methods to attributes, for use by cmp
sub lineage 
  { my( $att)= @_;
    my $elt= $att->{_elt};
    return( $elt, $elt->lineage);
  }

sub is_inside
  { my( $att, $node)= @_;
    return ($att->{_elt} == $node) || $att->{_elt}->is_inside( $node);
  }

1;


package HTML::TreeBuilder::XPath::Root;

use base 'HTML::TreeBuilder::XPath::Node';
    
sub getParentNode   { return (); }
sub getChildNodes   { my @content= ( $_[0]->{_root}); return wantarray ? @content : \@content; }
sub getAttributes   { return []        }
sub isDocumentNode  { return 1         }

# added to provide element-like methods to root, for use by cmp
sub lineage {  return ($_[0]); }
sub is_inside { return 0; }
sub cmp { return $_[1]->isa( ' HTML::TreeBuilder::XPath::Root') ? 0 : 1; }

1;

__END__
=head1 NAME

HTML::TreeBuilder::XPath - add XPath support to HTML::TreeBuilder

=head1 SYNOPSIS

  use HTML::TreeBuilder::XPath;
  my $tree= HTML::TreeBuilder::XPath->new;
  $tree->parse_file( "mypage.html");
  my $nb=$tree->findvalue( '/html/body//p[@class="section_title"]/span[@class="nb"]');
  my $id=$tree->findvalue( '/html/body//p[@class="section_title"]/@id');

  my $p= $html->findnodes( '//p[@id="toto"]')->[0];
  my $link_texts= $p->findvalue( './a'); # the texts of all a elements in $p
  
  
=head1 DESCRIPTION

This module adds typical XPath methods to HTML::TreeBuilder, to make it
easy to query a document.

=head1 METHODS

Extra methods added both to the tree object and to each element:

=head2 findnodes ($path)

Returns a list of nodes found by C<$path>.
In scalar context returns an C<Tree::XPathEngine::NodeSet> object.

=head2 findnodes_as_string ($path)

Returns the text values of the nodes, as one string.

=head2 findnodes_as_strings ($path)

Returns a list of the values of the result nodes. 

=head2 findvalue ($path)

Returns either a C<Tree::XPathEngine::Literal>, a C<Tree::XPathEngine::Boolean>
or a C<Tree::XPathEngine::Number> object. If the path returns a NodeSet,
$nodeset->xpath_to_literal is called automatically for you (and thus a
C<Tree::XPathEngine::Literal> is returned). Note that
for each of the objects stringification is overloaded, so you can just
print the value found, or manipulate it in the ways you would a normal
perl value (e.g. using regular expressions).

=head2 exists ($path)

Returns true if the given path exists.

=head2 matches($path)

Returns true if the element matches the path.

=head2 find ($path)

The find function takes an XPath expression (a string) and returns either a
Tree::XPathEngine::NodeSet object containing the nodes it found (or empty if
no nodes matched the path), or one of XML::XPathEngine::Literal (a string),
XML::XPathEngine::Number, or XML::XPathEngine::Boolean. It should always
return something - and you can use ->isa() to find out what it returned. If
you need to check how many nodes it found you should check $nodeset->size.
See L<XML::XPathEngine::NodeSet>.

=head2 as_XML_clean ($optional_indent_level)

HTML::TreeBuilder's C<as_XML> output is not really nice to look at, so
I added a new method, that can be used as a simple replacement for it. 
It escapes only the '<', '>' and '&' (plus '"' in attribute values), and
wraps CDATA elements in CDATA sections.

The C<$optional_indent_level> defaults to the level in the original HTML
document (ie you probably don't have to use it)

This method is currently in alpha state. Ping me if you want other options added
to it (wrapping?).

=head1 SEE ALSO

L<HTML::TreeBuilder>

L<XML::XPathEngine>

=head1 AUTHOR

Michel Rodriguez, E<lt>mirod@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Michel Rodriguez

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
