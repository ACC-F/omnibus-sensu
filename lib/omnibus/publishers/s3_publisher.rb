#
# Copyright 2012-2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus
  class S3Publisher < Publisher
    def publish(&block)
      log.info(log_key) { 'Starting S3 publisher' }
      safe_require('uber-s3')

      packages.each do |package|
        # Make sure the package is good to go!
        log.debug(log_key) { "Validating '#{package.name}'" }
        package.validate!

        # Upload the metadata first
        log.debug(log_key) { "Uploading '#{package.metadata.name}'" }
        client.store(key_for(package, package.metadata.name), package.metadata.to_json,
          access: access_policy,
        )

        # Upload the actual package
        log.info(log_key) { "Uploading '#{package.name}'" }
        client.store(key_for(package, package.name), package.content,
          access: access_policy,
          content_md5: package.metadata[:md5],
        )

        # If a block was given, "yield" the package to the caller
        block.call(package) if block
      end
    end

    private

    #
    # The actual S3 client object to communicate with the S3 API.
    #
    # @return [UberS3]
    #
    def client
      @client ||= UberS3.new(
        access_key:        Config.publish_s3_access_key,
        secret_access_key: Config.publish_s3_secret_key,
        bucket:            @options[:bucket],
        adaper:            :net_http,
      )
    end

    #
    # The unique upload key for this package. The additional "stuff" is
    # postfixed to the end of the path.
    #
    # @param [Package] package
    #   the package this key is for
    # @param [Array<String>] stuff
    #   the additional things to prepend
    #
    # @return [String]
    #
    def key_for(package, *stuff)
      File.join(
        package.metadata[:platform],
        package.metadata[:platform_version],
        package.metadata[:arch],
        package.name,
        *stuff,
      )
    end

    #
    # The access policy that corresponds to the +s3_access+ given in the
    # initializer option. Any access control that is not the strict string
    # +"public"+ is assumed to be private.
    #
    # @return [Symbol]
    #   the UberS3-ready access policy
    #
    def access_policy
      if @options[:acl].to_s == 'public'
        :public_read
      else
        :private
      end
    end
  end
end
