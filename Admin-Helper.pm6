class POE6::Admin-Helper {
  has Int $!App_die_on_status_error;
  
  submethod BUILD($die_on_status_error?) {
    if $die_on_status_error { $!App_die_on_status_error = $die_on_status_error; }
  }
  
  method !__get_die_on_status_error {
    return $!App_die_on_status_error;
  }
  
  ## delegation method. Cannot not look up attribute values in this usage, so all values
  ## must be passed in.
  method __goto_die( :$file?, :$class!, :$method!, :$line!, :$why = '', :$App_die_on_status_error) {
	if $App_die_on_status_error {
		die "Process requirements not met!\n\t$file class [" ~ $class ~ "] in method [" ~ $method ~ "] at line $line\n\tRE: $why\n\tdying to fix\n";
	}
  }

  method goto_die( :$file?, :$class!, :$method!, :$line!, :$why = '') {
	if $!App_die_on_status_error {
		die "Process requirements not met!\n\t$file class [" ~ $class ~ "] in method [" ~ $method ~ " ] at line $line\n\tRE: $why\n\tdying to fix\n";
	}
  }
}

