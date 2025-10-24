defmodule ExWallet.TelemetryUtils do
  require Logger

  def measure(metric, function) when is_function(function) and is_atom(metric) do
    run_measurement([metric], function)
  end

  def measure(metrics, function) when is_function(function) and is_list(metrics) do
    run_measurement(metrics, function)
  end

  # https://hexdocs.pm/phoenix/telemetry.html
  defp run_measurement(metrics, function) do
    start_time = System.monotonic_time()

    try do
      function.()
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__
        Logger.debug("Telemetry error: #{inspect(kind)} - #{inspect(reason)}")

        :erlang.raise(kind, reason, stacktrace)
    else
      result ->
        duration = System.monotonic_time() - start_time

        atoms = metrics |> Enum.map(&atomize/1)
        evt_name = [:ex_wallet, :wallet] ++ atoms

        Logger.debug("Telemetry event: #{inspect(evt_name)} - #{duration} ms")

        :telemetry.execute(evt_name, %{duration: duration}, %{})

        result
    end
  end

  defp atomize(a) when is_atom(a), do: a
  defp atomize(s) when is_binary(s), do: String.to_existing_atom(s)
end
