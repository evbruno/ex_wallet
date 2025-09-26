defmodule ExWallet.TelemetryUtils do
  require Logger

  def measure(metric, function) when is_function(function) and is_atom(metric) do
    run_measurement([metric], function)
  end

  def measure(metrics, function) when is_function(function) and is_list(metrics) do
    run_measurement(metrics, function)
  end

  defp run_measurement(metrics, function) do
    {elapsed_us, result} = :timer.tc(fn -> function.() end)
    elapsed_ms = System.convert_time_unit(elapsed_us, :microsecond, :millisecond)

    atoms = metrics |> Enum.map(&atomize/1)
    evt_name = [:ex_wallet, :wallet] ++ atoms

    Logger.debug("Telemetry event: #{inspect(evt_name)} - #{elapsed_ms}ms")

    :telemetry.execute(
      evt_name,
      %{duration: elapsed_ms},
      %{}
    )

    result
  end

  defp atomize(a) when is_atom(a), do: a
  defp atomize(s) when is_binary(s), do: String.to_existing_atom(s)
end
