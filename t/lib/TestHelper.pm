package TestHelper;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(initialize_test_js_instance);

use File::Path qw(make_path);
use File::Temp qw(tempdir tempfile);
use Hash::Merge::Simple qw(merge);

use RSP::JS::Engine::SpiderMonkey;
use RSP::Config;

sub initialize_test_host {
    my ($test_config) = @_;
    my $tmp_dir = tempdir();
    my $tmp_dir2 = tempdir();

    make_path("$tmp_dir2/actuallyhere.com/js");
    open(my $fh, ">", "$tmp_dir2/actuallyhere.com/js/bootstrap.js");
    print {$fh} "function main() { return 'hello world'; }";
    close $fh;

    my $config = {
        '_' => { root => $tmp_dir },
        rsp => { hostroot => $tmp_dir2 },
        'host:foo' => { alternate => 'actuallyhere.com' },
    };

    return merge($test_config, $config);
}

sub initialize_test_js_instance {
    my ($test_config) = @_;

    $test_config = initialize_test_host($test_config);

    my $conf = RSP::Config->new(config => $test_config);
    my $host = $conf->host('foo');

    my $je = RSP::JS::Engine::SpiderMonkey->new;
    $je->initialize;
    my $ji = $je->create_instance({ config => $host });
    $ji->initialize;

    return wantarray ? ($ji, $conf) : $ji;
}

1;
