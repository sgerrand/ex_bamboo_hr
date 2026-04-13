defmodule BambooHR.ApplicationTest do
  use ExUnit.Case, async: true

  describe "start/2" do
    test "starts the application supervisor" do
      assert {:ok, pid} = BambooHR.Application.start(:normal, [])
      assert Process.alive?(pid)
      assert Process.whereis(BambooHR.Supervisor) == pid
    end

    test "supervisor is registered under expected name" do
      {:ok, pid} = BambooHR.Application.start(:normal, [])
      assert Process.whereis(BambooHR.Supervisor) == pid
    end

    test "supervisor reports expected child counts" do
      {:ok, pid} = BambooHR.Application.start(:normal, [])

      assert %{active: 0, specs: 0, supervisors: 0, workers: 0} =
               Supervisor.count_children(pid)
    end
  end
end
