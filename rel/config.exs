# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html


# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :"idb6!TXnF:PR5;2N]`/9)8rF1=X>g30XWIr[^By|mwn%[eDjJb|y>=:<g(0zZ:xI"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"tXtrk%2U/Zwm(A;Hu%*n{!pa;E00lDf3PW7BMp.Ugk2<_N3o>L(Yg{wKo[ezTECK"
  set vm_args: "rel/vm.args"
  set config_providers: [
    {Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/config/secret.exs"]}
  ]
  set overlays: [
    {:mkdir, "config"},
    {:copy, "rel/config/secret.exs", "config/secret.exs"},
    {:copy, "rel/lichat.service", "lichat.service"},
    {:copy, "config/blacklist.txt", "config/blacklist.txt"},
    {:copy, "config/banner.txt", "config/banner.txt"},
    {:copy, "config/cert.pem", "config/cert.pem"},
    {:copy, "config/key.pem", "config/key.pem"},
  ]
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix distillery.release`, the first release in the file
# will be used by default

release :lichat do
  set version: current_version(:lichat)
end

