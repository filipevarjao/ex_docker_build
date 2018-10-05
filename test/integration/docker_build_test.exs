defmodule ExDockerBuild.Integration.DockerBuildTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  alias ExDockerBuild.DockerBuild

  @moduletag :integration

  describe "bind mount host dir into container" do
    @cwd System.cwd!()
    @file_path Path.join([@cwd, "myfile.txt"])

    setup do
      on_exit(fn ->
        File.rm_rf!(@file_path)
      end)
    end

    test "build docker image binding a mount at build time" do
      instructions = [
        {"FROM", "alpine:latest"},
        {"VOLUME", @cwd <> ":/data"},
        {"RUN", "echo \"hello-world!!!!\" > /data/myfile.txt"},
        {"CMD", "[\"cat\", \"/data/myfile.txt\"]"}
      ]

      log =
        capture_log(fn ->
          assert {:ok, image_id} = DockerBuild.build(instructions, "")
        end)

      assert log =~ "STEP 1/4 : FROM alpine:latest"
      assert log =~ "pulling image alpine:latest"
      assert log =~ "STEP 2/4 : VOLUME #{@cwd}:/data"
      assert log =~ "STEP 3/4 : RUN echo \"hello-world!!!!\" > /data/myfile.txt"
      assert log =~ "STEP 4/4 : CMD [\"cat\", \"/data/myfile.txt\"]"
      # TODO: delete image on exit
      # on_exit(fn ->

      # end)
      assert File.exists?(@file_path)
      assert File.read!(@file_path) == "hello-world!!!!\n"
    end

    test "build docker image relative binding a mount at build time" do
      instructions = [
        {"FROM", "alpine:latest"},
        {"VOLUME", ".:/data"},
        {"RUN", "echo \"hello-relative-world!!!!\" > /data/myfile.txt"},
        {"CMD", "[\"cat\", \"/data/myfile.txt\"]"}
      ]

      log =
        capture_log(fn ->
          assert {:ok, image_id} = DockerBuild.build(instructions, "")
        end)

      assert log =~ "STEP 2/4 : VOLUME .:/data"
      # TODO: delete image on exit
      # on_exit(fn ->

      # end)
      assert File.exists?(@file_path)
      assert File.read!(@file_path) == "hello-relative-world!!!!\n"
    end
  end

  describe "mount a named volume" do
    test "build docker image mounting a named volume" do
      instructions = [
        {"FROM", "alpine:latest"},
        {"RUN", "mkdir /myvol"},
        {"RUN", "echo \"hello-world!!!!\" > /myvol/greeting"},
        {"VOLUME", "vol_storage"},
        {"VOLUME", "vol_storage:/myvol"},
        {"CMD", "[\"cat\", \"/myvol/greeting\"]"}
      ]

      log =
        capture_log(fn ->
          assert {:ok, image_id} = DockerBuild.build(instructions, "")

          with {:ok, container_id} <- ExDockerBuild.create_container(%{"Image" => image_id}),
               {:ok, ^container_id} <- ExDockerBuild.start_container(container_id),
               {:ok, [container_logs]} = ExDockerBuild.containers_logs(container_id),
               {:ok, ^container_id} <- ExDockerBuild.stop_container(container_id),
               :ok <- ExDockerBuild.remove_container(container_id) do
            assert container_logs =~ "hello-world!!!!"
          else
            error ->
              assert error == nil, "should not be an error"
          end
        end)

      assert log =~ "STEP 1/6 : FROM alpine:latest"
      assert log =~ "pulling image alpine:latest"
      assert log =~ "STEP 2/6 : RUN mkdir /myvol"
      assert log =~ "STEP 3/6 : RUN echo \"hello-world!!!!\" > /myvol/greeting"
      assert log =~ "STEP 4/6 : VOLUME vol_storage"
      assert log =~ "STEP 5/6 : VOLUME vol_storage:/myvol"
      assert log =~ "STEP 6/6 : CMD [\"cat\", \"/myvol/greeting\"]"
    end
  end
end
