# verify_circuit_breaker.exs
alias Voelgoedevents.Infrastructure.CircuitBreaker

service = :test_service

IO.puts("\n--- Starting Circuit Breaker Verification ---")

# 1. Verify Closed State
IO.puts("1. Testing Closed State (Success)")
{:ok, :success} = CircuitBreaker.call(service, fn -> :success end)
status = CircuitBreaker.get_status(service)
IO.puts("   -> OK | Status: #{inspect(status)}")

# 2. Trigger Failures
IO.puts("2. Triggering 5 Failures")
for i <- 1..5 do
  {:error, _} = CircuitBreaker.call(service, fn -> raise "fail" end)
  IO.puts("   -> Failure #{i}")
end

# 3. Verify Open State
IO.puts("3. Testing Open State")
status = CircuitBreaker.get_status(service)
IO.puts("   -> Status: #{inspect(status)}")
case CircuitBreaker.call(service, fn -> :should_not_run end) do
  {:error, :circuit_open} -> IO.puts("   -> Circuit is OPEN (Correct)")
  other -> IO.puts("   -> ERROR: Expected :circuit_open, got #{inspect(other)}")
end

# 4. Wait for Half-Open (Simulated)
IO.puts("4. Forcing Reset (Simulating 60s timeout)")
send(CircuitBreaker, {:reset_circuit, service})
Process.sleep(100)

# 5. Verify Half-Open
IO.puts("5. Testing Half-Open State")
status = CircuitBreaker.get_status(service)
IO.puts("   -> Status: #{inspect(status)}")
case CircuitBreaker.call(service, fn -> :recovered end) do
  {:ok, :recovered} -> IO.puts("   -> Half-Open allowed request (Correct)")
  other -> IO.puts("   -> ERROR: Expected success in Half-Open, got #{inspect(other)}")
end

# 6. Verify Closed Again
IO.puts("6. Verifying Circuit is Closed after success")
status = CircuitBreaker.get_status(service)
IO.puts("   -> Status: #{inspect(status)}")
case CircuitBreaker.call(service, fn -> :success end) do
  {:ok, :success} -> IO.puts("   -> Circuit is CLOSED (Correct)")
  other -> IO.puts("   -> ERROR: Expected success, got #{inspect(other)}")
end

IO.puts("--- Verification Complete ---\n")
