# POE6/Tiny

####
# This module is a 'Tiny' Perl6 fork of POE using Ingo's POE-0.0.1 module
# Author credits: (Perl6) POE-0.0.1, Ingo Blechschmidt C<< <iblech@web.de> >>
#                 (Perl5) POE-0.0.1, Ingo Blechschmidt C<< <iblech@web.de> >>
# 
# The intent is to satisfy simple POE needs in Perl6, not to re-write POE
# Therefore this module does not have all of the bookkeeping embedded within POE,
# and that surely makes the POE code more stable.
# Note. The 1st iteration of this code is nearly an identical fork of POE-0.0.1
#
####
#module POE6::Tiny-0.0.3;

my $p6_version = '0.0.3';

use POE6::Roles;
use POE6::Admin-Helper;
our $*App_die_on_status_error;
our $POE6::Session::Track = {};
our $POE6::Session::Alias-Lookup = {};

## set debug carping
our $*poe6_debug = 1;

####
# POE6 now uses a Kernel::Main role to bring in common methods
# This role has a call to the Build_Start method in the submethod Build
# in order to add custom startup functions
#
# The POE6::Kernel class is very simple - and is mostly one method, Build_Start()
####
class POE6::Kernel does Kernel::Main {

  ## starter method to override when adding custom BUILD actions
  method !Build_Start() {
	$*poe6_debug = 1;
  }

   method run() {
  }

}

####
# POE6 now uses a Session role to bring in common methods
#
# Your session object should be formed like the following:
#   class MySession does POE6::Session {
#     ...do stuff
#   }
#
####
# The previous POE::Session class looked like this...
####
class POE::Session {
  
  method session_id() {
	return $!SESSION_ID;
  }

  method link_kernel( $kernel! ) {
	$!POE6-KERNEL = $kernel;
  }
  
  method dispatch(Str $event, *@args) {
    die 'Please override &dispatch in your subclass of POE6::Session.';
  }

}

#
#Note. The global variable $POE::Kernal should be created outside of the class package
#  to ensure the namespace is populated. Otherwise a 'Cannot find symbol' error may occur.
  
##--Notepad++
