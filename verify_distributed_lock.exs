# verify_distributed_lock.exs
alias Voelgoedevents.Infrastructure.DistributedLock

IO.puts("\n--- Starting Distributed Lock Verification ---")

# Test 1: Basic Lock and Unlock
IO.puts("\n1. Testing Basic Lock/Unlock")
lock_key = "test:resource:1"
lock_value = "test-process-1"

case DistributedLock.lock(lock_key, lock_value, 5000) do
  :ok -> IO.puts("   ✓ Lock acquired successfully")
  {:error, reason} -> IO.puts("   ✗ Failed to acquire lock: #{inspect(reason)}")
end

case DistributedLock.unlock(lock_key, lock_value) do
  :ok -> IO.puts("   ✓ Lock released successfully")
  {:error, reason} -> IO.puts("   ✗ Failed to release lock: #{inspect(reason)}")
end

# Test 2: Concurrent Lock Attempts (Should Fail)
IO.puts("\n2. Testing Concurrent Lock Attempts")
lock_key2 = "test:resource:2"
lock_value1 = "process-1"
lock_value2 = "process-2"

case DistributedLock.lock(lock_key2, lock_value1, 5000) do
  :ok -> IO.puts("   ✓ Process 1 acquired lock")
  {:error, reason} -> IO.puts("   ✗ Process 1 failed: #{inspect(reason)}")
end

case DistributedLock.lock(lock_key2, lock_value2, 5000) do
  {:error, :lock_unavailable} -> IO.puts("   ✓ Process 2 correctly rejected (lock unavailable)")
  :ok -> IO.puts("   ✗ ERROR: Process 2 should not have acquired lock!")
  {:error, reason} -> IO.puts("   ✗ Unexpected error: #{inspect(reason)}")
end

# Cleanup
DistributedLock.unlock(lock_key2, lock_value1)

# Test 3: Unlock Safety (Wrong Value)
IO.puts("\n3. Testing Unlock Safety (Wrong Value)")
lock_key3 = "test:resource:3"
lock_value_correct = "correct-value"
lock_value_wrong = "wrong-value"

DistributedLock.lock(lock_key3, lock_value_correct, 5000)

case DistributedLock.unlock(lock_key3, lock_value_wrong) do
  {:error, :not_locked} -> IO.puts("   ✓ Unlock with wrong value correctly rejected")
  :ok -> IO.puts("   ✗ ERROR: Should not unlock with wrong value!")
  {:error, reason} -> IO.puts("   ✗ Unexpected error: #{inspect(reason)}")
end

# Cleanup with correct value
DistributedLock.unlock(lock_key3, lock_value_correct)

# Test 4: with_lock Convenience Function
IO.puts("\n4. Testing with_lock Convenience Function")
lock_key4 = "test:resource:4"

case DistributedLock.with_lock(lock_key4, 5000, fn ->
  IO.puts("   ✓ Executing critical section")
  :success
end) do
  {:ok, :success} -> IO.puts("   ✓ with_lock executed successfully")
  {:error, reason} -> IO.puts("   ✗ with_lock failed: #{inspect(reason)}")
end

# Test 5: Concurrent with_lock (Should Fail)
IO.puts("\n5. Testing Concurrent with_lock")
lock_key5 = "test:resource:5"

# Start async task to hold lock
task = Task.async(fn ->
  DistributedLock.with_lock(lock_key5, 2000, fn ->
    Process.sleep(1000)
    :task_completed
  end)
end)

# Give task time to acquire lock
Process.sleep(100)

# Try to acquire same lock (should fail)
case DistributedLock.with_lock(lock_key5, 500, fn ->
  :should_not_execute
end) do
  {:error, :lock_unavailable} -> IO.puts("   ✓ Concurrent with_lock correctly rejected")
  {:ok, _} -> IO.puts("   ✗ ERROR: Should not have acquired lock!")
  {:error, reason} -> IO.puts("   ✗ Unexpected error: #{inspect(reason)}")
end

# Wait for task to complete
Task.await(task)

# Test 6: TTL Expiration
IO.puts("\n6. Testing TTL Expiration (1 second lock)")
lock_key6 = "test:resource:6"
lock_value6 = "ttl-test"

DistributedLock.lock(lock_key6, lock_value6, 1000) # 1 second TTL
IO.puts("   ✓ Lock acquired with 1s TTL")
IO.puts("   → Waiting 1.5 seconds for expiration...")
Process.sleep(1500)

# Try to acquire again (should succeed after expiration)
case DistributedLock.lock(lock_key6, "new-value", 1000) do
  :ok -> IO.puts("   ✓ Lock re-acquired after TTL expiration")
  {:error, :lock_unavailable} -> IO.puts("   ✗ Lock should have expired!")
  {:error, reason} -> IO.puts("   ✗ Unexpected error: #{inspect(reason)}")
end

IO.puts("\n--- Verification Complete ---\n")
