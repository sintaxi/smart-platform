use inc::Module::Install;

name 'RSP';
all_from 'lib/RSP.pm';
license 'MIT';
perl_version '5.010001';

install_script 'bin/rsp';
install_script 'bin/rspkeymanagerd';

configure_requires 'Module::Build'; # temporary... Algo::C3 build breaks a huge dependency chain in a non-obvious way

test_requires 'Test::More' => 0;
test_requires 'Test::Exception' => 0;
test_requires 'mocked' => 0;

requires 'Net::RabbitMQ' => '0.1.0';
requires 'DBI' => 0;
requires 'SQL::Abstract' => 0;
requires 'Set::Object' => 0;
requires 'Imager' => 0;
requires 'Application::Config' => 0;
requires 'Mojo' => '0.999910';
requires 'MIME::Types' => 0;
requires 'Hash::Merge::Simple' => 0;
requires 'Digest::MD5' => 0;
requires 'Digest::SHA1' => 0;
requires 'Digest::HMAC_SHA1' => 0;
requires 'JSON::XS' => 0;
requires 'Scalar::Util' => 0;
requires 'JavaScript' => '1.15';
requires 'JavaScript::Runtime::OpcodeCounting' => "1.02";
requires 'Module::Load' => 0;
requires 'LWPx::ParanoidAgent' => 0;
requires 'Cache::Memcached::Fast' => 0;
requires 'Class::Accessor::Chained' => 0;
requires 'Data::UUID::Base64URLSafe' => 0;
requires 'Scalar::Util::Numeric' => 0;
requires 'Image::Math::Constrain' => 0;
requires 'File::MMagic' => 0;
requires 'DBD::SQLite' => 0;
requires 'DBD::mysql' => 0;
requires 'Moose' => 0;
requires 'Clone' => 0;
requires 'Try::Tiny' => 0;
requires 'File::Path' => 0;
requires 'File::Temp' => 0;
requires 'File::Spec' => 0;
requires 'Cwd' => 0;
requires 'Log::Dispatch::Config' => 0;

tests_recursive();
auto_install;

WriteAll();
