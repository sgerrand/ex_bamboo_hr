defmodule BambooHR.ApplicationTest do
  use ExUnit.Case, async: true

  describe "start/2" do
    test "starts the application supervisor" do
      assert {:ok, pid} = BambooHR.Application.start(:normal, [])
      assert Process.alive?(pid)
      assert Process.whereis(BambooHR.Supervisor) == pid
    end

    test "supervisor has correct configuration" do
      {:ok, pid} = BambooHR.Application.start(:normal, [])

      # Get supervisor configuration
      assert {:state, {:local, supervised_module}, strategy, {[], %{}}, :undefined, _intensity,
              _period, [], 0, _auto_shutdown, Supervisor.Default,
              {:ok, {config, []}}} = :sys.get_state(pid)

      # Verify supervisor configuration
      assert strategy == :one_for_one
      assert config[:strategy] == :one_for_one
      assert supervised_module == BambooHR.Supervisor
    end
  end
end
