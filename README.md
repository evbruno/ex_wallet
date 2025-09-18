# ExWallet

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Warning

**Do not store your crendentials with real funds here! This is a test!**

Running:

_the secret has to be at least 64 bytes..._

```bash
docker run --rm --name local-ex-wallet \
  -e DATABASE_PATH=/tmp/foo.db \
  -e SECRET_KEY_BASE=Tydw4ZX+IPZxkRZDPZ0UnR3YHdhZxRfACePkuTauzUWpccRgYek6IQw1x47P5Nwa \
  -p 4000:4000 \
  docker.io/educhaos/ex-wallet:v0.0.1
```