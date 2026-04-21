defmodule BambooHR.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = BambooHR.Application.start(:normal, [])

    on_exit(fn ->
      try do
        Supervisor.stop(pid)
      catch
        :exit, _ -> :ok
      end
    end)

    %{pid: pid}
  end

  describe "start/2" do
    test "starts the application supervisor", %{pid: pid} do
      assert Process.alive?(pid)
      assert Process.whereis(BambooHR.Supervisor) == pid
    end

    test "supervisor is registered under expected name", %{pid: pid} do
      assert Process.whereis(BambooHR.Supervisor) == pid
    end

    test "supervisor reports expected child counts", %{pid: pid} do
      assert %{active: 0, specs: 0, supervisors: 0, workers: 0} =
               Supervisor.count_children(pid)
    end
  end
end
