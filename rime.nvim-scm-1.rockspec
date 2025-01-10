local modrev, specrev = "scm", "-1"

rockspec_format = "3.0"
package = "rime.nvim"
version = modrev .. specrev

description = {
  summary = "🖼️ Bringing Rime to Neovim.",
  detailed = "",
  labels = { "neovim", "neovim-plugin" },
  homepage = "https://github.com/imkerberos/rime.nvim",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
}

source = {
  url = "git://github.com/imkerberos/rime.nvim"
}

external_dependencies = {
}

test_dependencies = {}

build = {
  type = "builtin",
  copy_directories = { "after" },
  modules = {
    rime = {
      sources = { "./rime/rime.c" },
      defines = {},
      incdirs = { "/nix/store/x9wcy82zsmg6xkxx88n5dbikrvw662fn-librime-1.12.0/include" },
      libdirs = { "/nix/store/x9wcy82zsmg6xkxx88n5dbikrvw662fn-librime-1.12.0/lib" },
      libraries = { "rime" },
    }
  }
}

-- vim: ft=lua ts=2 sw=2 et:
