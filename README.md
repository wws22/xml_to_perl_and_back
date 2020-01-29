           This small program shows the way to manage arrays and values at given XML file.
           That way doesn't keep order for XML node sequences.

       CLI using
               $./xmlrw.pl xmlrw.xml >new_xmlrw.xml
               $./xmlrw.pl xmlrw.xml -d >new_xmlrw.txt
               $./xmlrw.pl new_xmlrw.txt >one_more_xmlrw.xml
               $diff -uN new_xmlrw.xml one_more_xmlrw.xml

       Perl programming
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

