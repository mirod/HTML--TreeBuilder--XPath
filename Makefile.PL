use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'HTML::TreeBuilder::XPath',
    VERSION_FROM      => 'lib/HTML/TreeBuilder/XPath.pm', # finds $VERSION
    PREREQ_PM         => { XML::XPathEngine => 0.08, HTML::TreeBuilder => 0, }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/HTML/TreeBuilder/XPath.pm', # retrieve abstract from module
       AUTHOR         => 'Michel Rodriguez <mrodrigu@localdomain>') : ()),
);
