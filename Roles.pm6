# POE6/Roles

####
# Roles module
# $p6_version = '0.0.2';
#
# Within-
# module POE6::Tiny;
####

my $p6_version = '0.0.1';

use POE6::Admin-Helper;

role POE6::Session {
  has $!SESSION_ID;
  has $.IS_SESSION;
  has $!SESSION_NAME;
  has $!SESSION_ALIAS;
  has Int $.SESSION_CTR;
  has $!POE6-KERNEL;
  has %!SESS_OBJECT_STATES;
  has POE6::Admin-Helper $!admin_helper handles POE6::Admin-Helper.new();
  
  submethod BUILD(:$poe_kernel?,:$session_alias?,:%object_states?) {
	$!IS_SESSION = 1;
	$!SESSION_NAME = self.WHICH;
	if self.WHICH !~~ /\|(\d+)/ {
		my $method = &?ROUTINE.name;
		$!admin_helper.__goto_die( 
			file => $?FILE, 
			class => ::?CLASS.^name, 
			method => $method, 
			line => $?LINE, 
			why => "Bad ID match["~self.WHICH~"] for[$!SESSION_ID]", 
			App_die_on_status_error => $*App_die_on_status_error,
		);
	}
	$!SESSION_ID = $0;
	my $ctr = $POE6::Session::Track.elems;
	$ctr++;
    $!SESSION_CTR = $ctr;
	$POE6::Session::Track.push: ( $!SESSION_ID => $!SESSION_CTR );
	if $session_alias { $!SESSION_ALIAS = $session_alias; }
	
	# if sent, add POE::Kernel to session state
	if $poe_kernel {
		$!POE6-KERNEL = $poe_kernel;
	}

	%!SESS_OBJECT_STATES.push: ( '_start' => '_poe_start' );
	%!SESS_OBJECT_STATES.push: ( '_stop' => '_poe_stop' );
  }
  
  method session_id(Int :$session_id?) {
	if $session_id { $!SESSION_ID = $session_id; }
	return $!SESSION_ID;
  }
  method session_alias(Int :$session_alias?) {
	if $session_alias { $!SESSION_ALIAS = $session_alias; }
	if !$!SESSION_ALIAS { return $!SESSION_NAME; }
	return $!SESSION_ALIAS;
  }

  method link_kernel( $kernel! ) {
	$!POE6-KERNEL = $kernel;
  }
  
  method dispatch(Str $event, *@args) {
    die 'Please override &dispatch in your subclass of POE6::Session.';
  }

  method delay(Str $event, Int $timeout, *@args) {
	$!POE6-KERNEL.delay( self, $event, $timeout, @args );
	return True;
  }
  method yield( Str $event, *@args) {
	$!POE6-KERNEL.yield( self, $event, @args );
	return True;
  }
  method post( Str $event, *@args) {
	my $r = $!POE6-KERNEL.post( self, $event, @args );
	return $r;
  }

}
