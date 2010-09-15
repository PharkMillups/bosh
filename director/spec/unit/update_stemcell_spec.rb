require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::Jobs::UpdateStemcell do

  def gzip(string)
    result = StringIO.new
    zio = Zlib::GzipWriter.new(result)
    zio.mtime = 1
    zio.write(string)
    zio.close
    result.string
  end

  def create_stemcell(name, version, cloud_properties, image)
    io = StringIO.new

    manifest = {
      "name" => name,
      "version" => version,
      "cloud_properties" => cloud_properties
    }

    Archive::Tar::Minitar::Writer.open(io) do |tar|
      tar.add_file("stemcell.MF", {:mode => "0644", :mtime => 0}) {|os, _| os.write(manifest.to_yaml)}
      tar.add_file("image", {:mode => "0644", :mtime => 0}) {|os, _| os.write(image)}
    end

    io.close
    gzip(io.string)
  end


  before(:each) do
    @task = mock("task")
    @cloud = mock("cloud")

    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    Bosh::Director::Models::Task.stub!(:[]).with(1).and_return(@task)

    stemcell_contents = create_stemcell("jeos", 5, {"ram" => "2gb"}, "image contents")
    @stemcell_file = Tempfile.new("stemcell_contents")
    File.open(@stemcell_file.path, "w") {|f| f.write(stemcell_contents)}
  end

  after(:each) do
    FileUtils.rm_rf(@stemcell_file.path)
  end

  it "should upload the stemcell" do
    @task.should_receive(:state=).with(:processing)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @task.should_receive(:state=).with(:done)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) {|f| f.read}
      contents.should eql("image contents")
    end

    stemcell = mock("stemcell")
    stemcell.should_receive(:name=)
    stemcell.should_receive(:version=)
    stemcell.should_receive(:cid=)
    stemcell.should_receive(:save!)

    Bosh::Director::Models::Stemcell.stub!(:new).and_return(stemcell, nil)

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(1, @stemcell_file.path)
    update_stemcell_job.perform
  end

  it "should cleanup the stemcell file" do
    @task.should_receive(:state=).with(:processing)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @task.should_receive(:state=).with(:done)
    @task.should_receive(:timestamp=)
    @task.should_receive(:save!)

    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) {|f| f.read}
      contents.should eql("image contents")
    end

    stemcell = mock("stemcell")
    stemcell.should_receive(:name=)
    stemcell.should_receive(:version=)
    stemcell.should_receive(:cid=)
    stemcell.should_receive(:save!)

    Bosh::Director::Models::Stemcell.stub!(:new).and_return(stemcell, nil)

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(1, @stemcell_file.path)
    update_stemcell_job.perform

    File.exist?(@stemcell_file.path).should be_false
  end

end