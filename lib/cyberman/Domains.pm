package cyberman::Domains;

use Dancer2 appname => "cyberman";
use Dancer2::Plugin::Database;

use cyberman::Helper qw(auth_test);
use if config->{"use_nsd"}, "NSD::Interface";

get '/domains' => sub {
  return auth_test() if auth_test();

  my @domains = database->quick_select(
    "domain",
    {
      "ownerid" => vars->{"auth"},
    },
  );

  template 'domains' => {
    "domains" => \@domains,
  }
};

post '/domains/new' => sub {
  return auth_test() if auth_test();

  my %errs;

  if (!param("name")) {
    $errs{"e_no_name"} = 1;
  }

  my $name = lc param("name");

  if (scalar(keys(%errs)) == 0) {
    if (param("name") !~ m/^[a-z0-9]([a-z0-9\-_]*[a-z0-9])?$/) {
      $errs{"e_chars"} = 1;
    }
  }

  if (scalar(keys(%errs)) == 0) {
    my $result = database->quick_select(
      "domain",
      {
        "name" => param("name"),
      },
    );

    if ($result) {
      $errs{"e_exists"} = 1;
    }
  }

  if (scalar(keys(%errs)) != 0) {
    return template 'domains/new' => {
      %errs,
      error => 1,
    };
  }

  # TODO: send domains to nsd

  database->quick_insert(
    "domain",
    {
      "name" => $name,
      "ownerid" => vars->{"auth"},
    },
  );

  template 'redir' => {
    "redir" => "../domains?new=$name",
  };
};

get '/domains/:id/remove' => sub {
  my $domain = database->quick_select(
    "domain",
    {
      "id" => param("id"),
    },
  );

  return auth_test($domain->{"ownerid"}) if auth_test($domain->{"ownerid"});

  template 'domains/remove.tt' => {
    "domain" => $domain,
  };
};

post '/domains/:id/remove' => sub {
  my $domain = database->quick_select(
    "domain",
    {
      "id" => param("id"),
    },
  );

  if (!$domain) {
    # quick and dirty error that shouldn't really appear
    return "No such domain!";
  }

  return auth_test($domain->{"ownerid"}) if auth_test($domain->{"ownerid"});

  database->quick_delete(
    "domain",
    {
      "id" => param("id"),
    },
  );

  template redir => {
    redir => "../../domains?removed=$domain->{name}",
  };
};

true;
