
UserTag if-mm Order function name
UserTag if-mm addAttr
UserTag if-mm attrAlias key name
UserTag if-mm hasEndTag
UserTag if-mm Routine <<EOR
sub {
	my($func, $field, $opt, $text) = @_;

	my $record;
	my $status;

	my $reverse;
	$reverse = $func =~ s/^\s*!\s*//;

	my $extended = '';
	$extended = $1 if $field =~ s/(=.*)//;

	my ($group, @groups);
	$text = 1 if ! $text;
  CHECKIT: {
	if ($group or ! ($record = $Vend::UI_entry) ) {
		$record = ui_acl_enabled($group);
		if ( ! ref $record) {
			$status = $record;
			last CHECKIT;
		}
	}
	($status = 0, last CHECKIT) if ! UI::Primitive::is_logged();
	($status = 1, last CHECKIT) if $record->{super};
	$func = lc $func;
	($status = 1, last CHECKIT) if $func eq 'logged_in';

	my %acl_func = qw/
						fields	fields
						field	fields
						columns	fields
						column	fields
						col   	fields
						row		keys
						rows	keys
						key		keys
						keys	keys
						owner_field	owner_field
						owner	owner_field
					/;
	
	my %file_func = qw/
						page	pages
						file	files
						pages	pages
						files	files
					/;

	my %bool_func = qw/
						config   1
						reconfig 1
					/;

	my %paranoid = qw/
						mml             1
						sql             1
						report          1
						add_delete      1
						add_field       1
						journal_update  1
					/;
	my %yesno_func = qw/
						functions  functions
						advanced  functions
						tables  tables
						table   tables
					/;

	my $table = $CGI::values{mv_data_table} || $::Values->{mv_data_table};
	
	if($yesno_func{$func} eq 'tables') {
		$opt->{table} = $field if ! $opt->{table};
		$opt->{table} =~ s/^=/$table/;
	}
	elsif($yesno_func{$func} eq 'functions') {
		$opt->{table} = $field;
	}

	$table = $opt->{table} || $table;

	my $acl;
	my $check;
	$status = 0, last CHECKIT if $func eq 'super';
	if($check = $file_func{$func}) {
		$status = 1, last CHECKIT unless $record->{$check};
		my $file = $field || $Global::Variable->{MV_PAGE};
		# strip trailing slashes for checks on directories
		$file =~ s%/+$%%;                     
		my @files =  UI::Primitive::list_glob($record->{$check}, $opt->{prefix});
		if(! @files) {
			$status = '';
			last CHECKIT;
		}
		$status = ui_check_acl("$file$extended", join(" ", @files));
		last CHECKIT;
	}
	if($bool_func{$func} ) {
		$status = $record->{$func};
		last CHECKIT;
	}
	if($check = $yesno_func{$func} ) {
		my $v;
		if($v = $record->{"yes_$check"}) {
			$status = ui_check_acl("$table$extended", $v);
		}
		else {
			$status = 1;
		}
		if($v = $record->{"no_$check"}) {
			$status &&= ! ui_check_acl("$table$extended", $v);
		}
		last CHECKIT;
	}
	if(! ($check = $acl_func{$func}) ) {
		my $default = $func =~ /^no_/ ? 0 : 1;
		$status = $default, last CHECKIT unless $record->{$func};
		$status = ui_check_acl("$table$extended", $record->{$func});
		last CHECKIT;
	}

	# Now it is definitely a job for table_control;
	$acl = UI::Primitive::get_ui_table_acl($table);

	$status = 1, last CHECKIT unless $acl;
	my $val;
	if($acl->{owner_field} and $check eq 'keys') {
		$status = ::tag_data($table, $acl->{owner_field}, $field)
					eq $Vend::username;
		last CHECKIT;
	}
	elsif ($check eq 'owner_field') {
		$status = length $acl->{owner_field};
		last CHECKIT;
	}
	$status = UI::Primitive::ui_acl_atom($acl, $check, $field);
  }
	if(! $status and $record and (@groups or $record->{groups}) ) {
		goto CHECKIT if $group = shift @groups;
		(@groups) = grep /\S/, split /\0,\s]+/, $record->{groups};
		($group, @groups) = map { s/^/:/; $_ } @groups;
		goto CHECKIT;
	}
	return $status
		? (
			Vend::Interpolate::pull_if($text, $reverse)
		  )
		: Vend::Interpolate::pull_else($text, $reverse);
}
EOR

