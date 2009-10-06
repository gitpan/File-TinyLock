#!/usr/local/bin/perl

use strict;
use File::TinyLock;

print "Testing locking code...\n";

print "using File::TinyLock v$File::TinyLock::VERSION\n";

my $LOCK    = '/tmp/test.lock';
my $MYLOCK1 = "/tmp/test.$$.lock1";
my $MYLOCK2 = "/tmp/test.$$.lock2";

my @errors;

my $lock = File::TinyLock->new(lock    => $LOCK,
                               mylock  => $MYLOCK1,
                               debug   => 1,
                               retrydelay => 2,
                        );

my $result = $lock->lock();
unless($result == 1){
    $lock->unlock();
    push @errors, "could not lock";
}

open(LOCK, $LOCK) || die "could not open $LOCK: $!\n";
chomp(my $line = <LOCK>);
close LOCK;
my($pid,$mylock) = split /:/, $line;

push @errors, "pid not found in $LOCK" unless($pid eq $$);
push @errors, "mylock not found" unless(-s $mylock);


my $locka = File::TinyLock->new(lock     => $LOCK,
                                mylock   => $MYLOCK2,
                                retries  => 2,
                                retrydelay => 2,
                                debug    => 1,
                         );
my $res = $locka->lock(); # SHOULD FAIL!
if($res){
    push @errors, "was able to lock twice";
    $locka->_unlock();
}

$lock->unlock();

push @errors, "$LOCK still exists" if( -f $LOCK );
push @errors, "$MYLOCK1 still exists" if( -f $MYLOCK1 );
push @errors, "$MYLOCK2 still exists" if( -f $MYLOCK2 );

if(@errors){
    foreach my $err (@errors){
        print "ERROR: $err\n";
    }
    die "too many errors\n";
}else{
	print "all tests completed sucessfully.\n"
}
