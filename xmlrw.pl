#!/usr/bin/env perl

use strict;
use warnings;
use English '-no_match_vars';
use version; our $VERSION = qw(1.01);
use 5.010;

use Carp qw(croak);
use Pod::Usage;
use Getopt::Long;
use Storable qw(dclone);
use File::Temp;
use Data::Dumper; $Data::Dumper::Sortkeys = 1; # To make Dump file comparable
                  $Data::Dumper::Purity   = 1; # To make Dump evaluating
use XML::Simple;
use XML::XPath;
use HTML::Entities;

=pod

=head1 NAME

    xmlrw.pl

=head1 USAGE

    xmlrw.pl [-help] [-d] <filename>

=head1 REQUIRED ARGUMENTS

=over 4

=item filename

    - the file to working for. Must be an XML or DUMP type

=back

=head1 OPTIONS

=over 4

=item -dump, -d

    - produced DUMP file instead of XML

=item -help, -h, -?

    - print brief usage info and exit

=item -man, -m

    - show man page and exit

=back

=cut

my $man;
my $help;
my $dump;
GetOptions(
    'help|h|?' => \$help,
    'man|m'    => \$man,
    'd|dump'   => \$dump,
) or pod2usage(1);

if ( defined $man ) {
    pod2usage( -verbose => 2 );
}

if ( defined $help ) {
    pod2usage(1);
}

my $filename = $ARGV[0];
if ( !defined $filename ) {
    pod2usage();
}

binmode STDOUT, ':encoding(UTF8)';  # Enable special characters. Ex: Straße ...
                                    # You should do that for any feature output file


# Let's try to determine type of the given file

open my $in, q{<}, $filename or croak "Can't open $filename";
binmode $in, ':encoding(UTF8)';
my $is_xml; # Is it real XML or DUMP
my $doc;    # Our XML document as a structure

my $beacon = <$in>;
if( $beacon =~ /^<\?xml\s+/msx ){

    # Looks like an XML
    close $in or croak "Can't close $filename";
    $doc = XMLin( $filename, forcearray => 1 );    #  NB! forcearray => 1 is very important here
    $is_xml = 1;

}
elsif( $beacon =~ /^\$VAR1\s+/msx ){

    # Looks like a DUMP
    $doc = eval 'my ' . $beacon . do { local $INPUT_RECORD_SEPARATOR = undef; <$in> };
    close $in or croak "Can't close $filename";

}
else{

    # Wrong type of the file
    close $in or croak "Can't close $filename";
    croak "$filename doesn't looks like anx XML or DUMP file";
}


########################################################
# When you are going to use the XPath expressions,
# you must have the real XML file
#
# Next part of code recreate file from  given DUMP
#
########################################################
my $tmpfh;  # We will keep FILEHANDLE of temporary XML file
if( ! $is_xml ){
    # Recreate a real XML file from the DUMP image
    $tmpfh = File::Temp->new(
        UNLINK   => 1,
        TEMPLATE => '/tmp/xmlrw_XXXXXXXXXX',
    );
    binmode $tmpfh, ':encoding(UTF8)';
    print $tmpfh xmlOut( $doc,
        rootname => 'Document',
        xmldecl  => '<?xml version="1.0" encoding="UTF-8"?>'
    );
    close $tmpfh or croak "Can't close temporary XML file ".$tmpfh->filename;

    $filename = $tmpfh->filename;

}
######################################################## End of preparation an XML file

############################# The XPath representation is more easy way to have some values
my $dom = XML::XPath->new( filename => $filename );

# Get some value by XPath
my $some_value = getValue( $dom, '//InitgPty/Nm' );    # // does mean to find all text of all nodes like
    #                                                       <InitgPty><Nm>Text</Nm></InitgPty>

    # May will be better to use
    # //InitgPty/Nm[1]  (Only first value)
    # or using an absolute path and/or postion
    # $some_value = getValue( $dom, '/Document/CstmrCdtTrfInitn/GrpHdr/InitgPty[1]/Nm[1]' );

    # or do not use the DOM and XPath
    # $some_value = $doc->{CstmrCdtTrfInitn}[0]->{GrpHdr}[0]->{InitgPty}[0]->{Nm}[0];

######################################################## End of example

# Create deep copy of XML node
my $branch      = $doc->{CstmrCdtTrfInitn}[0]->{GrpHdr}[0]->{InitgPty};
my $src_node    = $branch->[0];
my $target_node = dclone($src_node);

# Insert new node into the same branch
push @{$branch}, $target_node;

# Modify value of new node
$branch->[1]->{Nm}[0] = $some_value . ' new!';

# Example of removing the nodes
my $index_of_first_deleted_node = 0;    # That is first(old) node
my $how_much                    = 1;    # Only one node
splice( @{$branch}, $index_of_first_deleted_node, $how_much );

# Print the results of transformation
if ( defined $dump ) {

    say Dumper( reDump($doc) );

}
else {

    say xmlOut($doc);

}

### End of main

=head1 METHODS

=head2 getValue ($dom, $xpath)

    The function return decoded node text from $dom by given XPath value

        $dom              - required, XML::XPath object

        $xpath            - required, XPath expression. Ex: '//InitgPty/Nm'

=cut

sub getValue {
    my ( $DOM, $XPath ) = @_;
    return decode_entities( $DOM->getNodeText($XPath) );
}

=head2 reDump ($doc)

    The function rebuild XML::Simple object when it has been changed

        $doc              - required, XML::Simple object

=cut

sub reDump {
    my $clean_text = xmlOut(
        shift,
        rootname => 'Document',
        xmldecl  => '<?xml version="1.0" encoding="UTF-8"?>'
    );
    my $ft = File::Temp->new(
        UNLINK   => 1,
        TEMPLATE => '/tmp/xmlrw_XXXXXXXXXX',
    );
    binmode $ft, ':encoding(UTF8)';
    print $ft $clean_text;
    close $ft or croak "Can't close temporary file ".$ft->filename;
    return XMLin( $ft->filename, forcearray => 1 );
}

=head2 xmlOut ($doc)

    The function return ordered XML text for $doc

        $doc              - required, XML::Simple object

=cut

sub xmlOut {
    return XMLout(
        shift,
        rootname => 'Document',
        xmldecl  => '<?xml version="1.0" encoding="UTF-8"?>'
    );
}

1;
__END__
=head1 DESCRIPTION

    This small program shows the way to manage arrays and values at given XML file.
    That way doesn't keep order for XML node sequences.

=over 4

=item CLI using

    $./xmlrw.pl xmlrw.xml >new_xmlrw.xml
    $./xmlrw.pl xmlrw.xml -d >new_xmlrw.txt
    $./xmlrw.pl new_xmlrw.txt >one_more_xmlrw.xml
    $diff -uN new_xmlrw.xml one_more_xmlrw.xml

=item  Perl programming

    use Storable qw(dclone);
    use File::Temp;
    use Data::Dumper; $Data::Dumper::Sortkeys = 1; # To make Dump file comparable
                      $Data::Dumper::Purity   = 1; # To make Dump evaluating
    use XML::Simple;

    # Create object
    $doc = XMLin( 'xmlrw.xml', forcearray => 1 );

    # Get some node value
    $some_value = $doc->{CstmrCdtTrfInitn}[0]->{GrpHdr}[0]->{InitgPty}[0]->{Nm}[0];

    # Create deep copy of XML node
    my $branch      = $doc->{CstmrCdtTrfInitn}[0]->{GrpHdr}[0]->{InitgPty};
    my $src_node    = $branch->[0];
    my $target_node = dclone($src_node);

    # Insert new node into the same branch
    push @{$branch}, $target_node;

    # Modify value of new node
    $branch->[1]->{Nm}[0] = $some_value . ' new!';

    # Remove some nodes
    my $index_of_first_deleted_node = 0;    # That is first(old) node
    my $how_much                    = 1;    # Only one node
    splice( @{$branch}, $index_of_first_deleted_node, $how_much );

    # Print new XML
    print xmlOut($doc);

=back


=head1 DEPENDENCIES

XML::Simple is required

=over 4

=item Next modules required only for using with XPath expressions

    XML::XPath
    HTML::Entities

=back

=head1 AUTHOR

victor.selukov [at] gmail [dot] com

=head1 DIAGNOSTICS

=head1 EXIT STATUS

=head1 CONFIGURATION

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 LICENSE AND COPYRIGHT

=cut

