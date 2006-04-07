# File::Lock.pm
# $Id: Lock.pm,v 0.10 2006/04/06 16:53:32 jkister Exp $
# Copyright (c) 2006 Jeremy Kister.
# Released under Perl's Artistic License.

$File::Lock::VERSION = "0.10";

=head1 NAME

File::Lock - Utility to lock and unlock files.

=head1 SYNOPSIS

use File::Lock;

my $result = File::Lock::lock($file);
my $result = File::Lock::lock(file    => $file
                              timeout => 10,
                              debug   => 0);

my $result = File::Lock::unlock($file);
my $result = File::Lock::unlock(file    => $file);

my $result = File::Lock::check($file);
my $result = File::Lock::check(file    => $file);
	
=head1 DESCRIPTION

C<File::Lock> provides a C<lock>, C<unlock>, and C<check> function for
working with file locks.

=head1 CONSTRUCTOR

=over 4

=item Lock( [FILE] [,OPTIONS] );

If C<FILE> is not given, then it may instead be passed as the C<file>
option described below.

C<OPTIONS> are passed in a hash like fashion, using key and value
pairs.  Possible options are:

B<file> - The file to lock

B<timeout> - Number of seconds to continue trying to lock (Default: 10).

B<debug> - Print debugging info to STDERR (0=Off, 1=On).

=head1 RETURN VALUE

Here are a list of return codes of the C<lock> function and what they mean:

=item 0 The file is locked.

=item 1 The file is not found.

=item 2 Master lock exists and is not writable

=item 3 Could not unlink stale master lock

=item 4 Could not fork ps

=item 5 Could not read master lock

=item 6 Could not write to temporary lock

=item 7 The file is already locked.


.. and for the C<check> function:

=item 0 File is locked

=item 1 File is not locked

=item 2 permissions problems with lock files

.. and the C<unlock> function:

=item 0 File unlocked.

=item 1 Couldnt unlock file

=item 2 Couldnt unlink master lock

=item 3 Couldnt unlink temporary lock


=head1 EXAMPLES

  use File::Lock;
  my $file = shift;
  unless(defined($file)){
    print "file to lock: ";
    chop($file=<STDIN>);
  }
  my $result = File::Lock::lock($file);
  if($result){
    print "Could not lock: ${result}\n";
  }else{
    print "$file is now locked\n";
  }
	
	# do stuff to file

  if($result = File::Lock::unlock($file)){
    print "could not unlock $file: $result\n";
  }
  exit;


=head1 CAVEATS

This utility must be used by all code that works with the file you're
trying to lock.  Locking with C<File::Lock> will not keep someone
from using vi and editing the file.

If you leave lock files around (from not unlocking the file before
your code exits), C<File::Lock> will try its best to determine if the
lock files are stale or not.  This is best effort, and may yield
false positives.  For example, if your code was running as pid 1234
and exited without unlocking, stale detection may fail if there is
a new process running with pid 1234.

=head1 RESTRICTIONS

Locking will only remain successfull while your code is active.  You
can not lock a file, let your code exit, and expect the file to remain
locked; doing so will result in stale lock files left behind.  

lock file -> do stuff -> unlock file -> exit;

=head1 AUTHOR

<a href="http://jeremy.kister.net./">Jeremy Kister</a>

=cut

package File::Lock;

use strict;

sub Version { $File::Lock::VERSION }

sub check {
	my %arg;
	if(@_ % 2){
		my $file = shift;
		%arg = @_;
		$arg{file} = $file;
	}else{
		%arg = @_;
	}
	my $fqfile = $arg{file};

	return 1 unless(-f $fqfile);

	my ($file) = $fqfile =~ /([^\/]+)$/;
	my $dir = '.';
	if($fqfile =~ /^(.+)\/[^\/]+$/){
		$dir = $1;
	}
	if(-f "${dir}/${file}.lock"){
		if(open(LOCK, "${dir}/${file}.lock")){
			my $pid = <LOCK>;
			close LOCK;
			return 0 if(-f "${dir}/${file}.lock.${pid}"); # locked, maybe stale
		}else{
			warn "could not read $dir/$file.lock: $!\n" if($arg{debug} == 1);
			return 2;
		}
	}

	return 1; # not locked
}

sub unlock {
	my %arg;
	if(@_ % 2){
		my $file = shift;
		%arg = @_;
		$arg{file} = $file;
	}else{
		%arg = @_;
	}
	my $fqfile = $arg{file};

	return 1 unless(-f $fqfile);

	my ($file) = $fqfile =~ /([^\/]+)$/;
	my $dir = '.';
	if($fqfile =~ /^(.+)\/[^\/]+$/){
		$dir = $1;
	}

	if(my $x = File::Lock::check($fqfile)){
		warn "cannot unlock: $x\n" if($arg{debug} == 1);
		return 1;
	}else{
		if(unlink("${dir}/${file}.lock.$$")){
			if(unlink("${dir}/${file}.lock")){
				return 0; # unlocked
			}else{
				warn "could not unlink ${dir}/${file}.lock: $!\n" if($arg{debug} == 1);
				return 2; #
			}
		}else{
			warn "could not unlink ${dir}/${file}.lock.$$: $!\n" if($arg{debug} == 1);
			return 3;
		}
	}
}

sub lock {
	my %arg;
	if(@_ % 2){
		my $file = shift;
		%arg = @_;
		$arg{file} = $file;
	}else{
		%arg = @_;
	}
	my $fqfile = $arg{file};
	if(exists($arg{timeout})){
		warn "using timeout of $arg{timeout} seconds\n" if($arg{debug} == 1);
	}else{
		$arg{timeout} = 10;
		warn "using default timeout of 10 seconds\n" if($arg{debug} == 1);
	}

	return 1 unless(-f $fqfile);

	my ($file) = $fqfile =~ /([^\/]+)$/;
	my $dir = '.';
	if($fqfile =~ /^(.+)\/[^\/]+$/){
		$dir = $1;
	}
	if(-f "${dir}/${file}.lock"){
		unless(-w "${dir}/${file}.lock"){
			warn "cannot write to $dir/$file.lock: $!\n" if($arg{debug} == 1);
			return 2;
		}
	}
	my $pid;
	if(open(LOCK, ">${dir}/${file}.lock.$$")){
		print LOCK $$;
		close LOCK;

		for(my $n=0; $n <= $arg{timeout}; $n++){
			if(link("${dir}/${file}.lock.$$","${dir}/${file}.lock")){
				return 0; # locked.
			}else{
				# could not lock; find out why.
				if(open(CUR, "${dir}/${file}.lock")){
					$pid = <CUR>;
					close CUR;

					# could be a stale lock + a pid for a different prog QQQ
					if(open(SYS, "ps -p $pid |")){
						my $sys;
						while(<SYS>){
							if(/^\s*${pid}\s+/){
								$sys=1;
								last; # lock is current;
							}
						}
						unless($sys){
							# lock is stale;
							if(unlink("${dir}/${file}.lock")){
								warn "stale lock found with pid: $pid\n" if($arg{debug} == 1);
								next; # loop, try again.
							}else{
								unless(unlink("${dir}/${file}.lock.$$")){
									warn "could not unlink lock.$$: $!\n" if($arg{debug} == 1);
								}
								warn "could not unlink stale lock at ${dir}/${file}.lock: $!\n" if($arg{debug} == 1);
								return 3;
							}
						}
					}else{
						unless(unlink("${dir}/${file}.lock.$$")){
							warn "could not unlink lock.$$: $!\n" if($arg{debug} == 1);
						}
						warn "cannot fork ps -f: $!\n" if($arg{debug} == 1);
						return 4;
					}
				}else{
					unless(unlink("${dir}/${file}.lock.$$")){
						warn "could not unlink lock.$$: $!\n" if($arg{debug} == 1);
					}
					warn "could not open $dir/$file.lock: $!\n" if($arg{debug});
					return 5;
				}
			}
			sleep 1; # if link failed
		}
	}else{
		unless(unlink("${dir}/${file}.lock.$$")){
			warn "could not unlink lock.$$: $!\n" if($arg{debug} == 1);
		}
		warn "could not write to $dir/$file.lock.$$: $!\n" if($arg{debug} == 1);
		return 6;
	}

	unless($$ == $pid){
		# dont want to unlink tmp lock if we're the one who put it there
		# (from calling lock twice in same code)
		unless(unlink("${dir}/${file}.lock.$$")){
			warn "could not unlink lock.$$: $!\n" if($arg{debug} == 1);
		}
	}
	return 7; # file already locked
}

1;
