require 'typhoeus'
require 'tempfile'
require 'fileutils'
require 'fiber'
require 'rmt'
require 'rmt/http_request'

class RMT::Downloader

  class Exception < RuntimeError
  end

  attr_accessor :repository_url, :local_path, :concurrency, :logger, :auth_token

  def initialize(repository_url:, local_path:, auth_token: nil, logger: nil)
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    @repository_url = repository_url
    @local_path = local_path
    @concurrency = 4
    @auth_token = auth_token
    @logger = logger || Logger.new('/dev/null')
  end

  def download(remote_file, checksum_type = nil, checksum_value = nil)
    local_file = make_local_path(remote_file)

    request_fiber = Fiber.new do
      make_request(remote_file, local_file, request_fiber, checksum_type, checksum_value)
    end

    request_fiber.resume.run

    local_file
  end

  def download_multi(files)
    @queue = files
    @hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)

    @concurrency.times { process_queue }

    @hydra.run
  end

  protected

  def process_queue
    # Skip over files that already exist
    begin
      queue_item = @queue.shift
      return unless queue_item

      remote_file = queue_item.location
      local_file = make_local_path(remote_file)
    end while File.exist?(local_file) # rubocop:disable Lint/Loop

    # The request is wrapped into a fiber for exception handling
    request_fiber = Fiber.new do
      begin
        make_request(remote_file, local_file, request_fiber, queue_item[:checksum_type], queue_item[:checksum])
      rescue RMT::Downloader::Exception => e
        @logger.warn("× #{File.basename(local_file)} - #{e}")
      ensure
        process_queue
      end
    end

    @hydra.queue(request_fiber.resume)
  end

  def make_request(remote_file, local_file, request_fiber, checksum_type = nil, checksum_value = nil)
    uri = URI.join(@repository_url, remote_file)
    uri.query = @auth_token if (@auth_token && uri.scheme != 'file')

    if URI(uri).scheme == 'file' && !File.exist?(uri.path)
      raise RMT::Downloader::Exception.new("#{remote_file} - File does not exist")
    end

    downloaded_file = Tempfile.new('rmt', Dir.tmpdir, mode: File::BINARY, encoding: 'ascii-8bit')

    request = RMT::FiberRequest.new(
      uri.to_s,
      followlocation: true,
      download_path: downloaded_file,
      request_fiber: request_fiber,
      remote_file: remote_file
    )

    request.receive_headers

    request.receive_body
    request.verify_checksum(checksum_type, checksum_value) if (checksum_type && checksum_value)

    FileUtils.mv(downloaded_file.path, local_file)
    File.chmod(0o644, local_file)

    @logger.info("↓ #{File.basename(local_file)}")
  end

  def make_local_path(remote_file)
    filename = File.join(@local_path, remote_file.gsub(/\.\./, '__'))
    dirname = File.dirname(filename)

    FileUtils.mkdir_p(dirname)

    filename
  end

end
