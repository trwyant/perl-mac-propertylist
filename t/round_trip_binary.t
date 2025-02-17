use strict;
use warnings;

use File::Temp qw{tempfile};
use Test::More 0.88;	# Because of done_testing();

my $HAS_PLUTIL  = -x '/usr/bin/plutil';

{
    my $class = 'Mac::PropertyList';
    my @exports = qw{parse_plist plist_as_string};

    use_ok $class, @exports or BAIL_OUT( "$class did not compile\n" );
    can_ok $class, @exports;
}

{
    my $class = 'Mac::PropertyList::WriteBinary';
    my @exports = qw{as_string};

    use_ok $class, @exports or BAIL_OUT( "$class did not compile\n" );
    can_ok $class, @exports;
}

my $ORIGINAL_PLIST = create_plist();
my $BINARY_PLIST = as_string($ORIGINAL_PLIST);

subtest 'Mac::PropertyList' => sub {
    is_deeply(parse_plist($BINARY_PLIST), $ORIGINAL_PLIST, 'Round trip');
};

subtest 'plutil' => sub {
    my( $temp_fh, $temp_filename ) = tempfile();
    plan skip_all => 'Test requires plutil'
        unless my $util = plutil->new( $temp_filename );

    binmode $temp_fh;
    print { $temp_fh } $BINARY_PLIST;

    SKIP: {
        is_deeply(
            parse_plist( $util->slurp(binary => 0) ),
            $ORIGINAL_PLIST,
            'Read binary plist converted to xml by plutil' );
    }

    seek $temp_fh, 0, 0;
    binmode $temp_fh, ':encoding(utf-8)';
    print { $temp_fh } plist_as_string( $ORIGINAL_PLIST );

    SKIP: {
        is_deeply(
            parse_plist( $util->slurp(binary => 1) ),
            $ORIGINAL_PLIST,
            'Read xml plist converted to binary bu plutil' );
    }

};

done_testing();

sub create_plist {
    my @integers;
    foreach my $value ( qw{
            0
            1
            255
            256
            65535
            65536
            4294967295
            4294967296
            9223372036854775807
            -1
            -255
            -256
            -65536
            -4294967296
            -9223372036854775808
        }
    ) {
        push @integers, Mac::PropertyList::integer->new( $value );
    }
    return Mac::PropertyList::dict->new(
        {
            integers    => Mac::PropertyList::array->new( \@integers ),
        },
    );
}

package plutil;

use Test::More;

sub new {
    my ($class, $plist_filename) = @_;
    my $util_path = '/usr/bin/plutil';
    -x $util_path
        or return;
    return bless {
        plist_filename  => $plist_filename,
        util_path       => $util_path,
    }, $class;
}

sub slurp {
    my ($self, %arg) = @_;
    my ($encoding, $format) = $arg{binary} ?
        ( qw{raw binary1} ) :
        ( qw{encoding(utf-8) xml1} );
    open my $pipe_fh, "-|:$encoding",
        $self->{util_path}, qw{-convert}, $format, qw{-o -},
        $self->{plist_filename}
        or skip "Failed to pipe from plutil: $!";
    local $/ = undef;   # slurp mode
    return <$pipe_fh>;
}

# ex: set textwidth=72 tabstop=4 expandtab :
