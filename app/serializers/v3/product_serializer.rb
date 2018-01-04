class V3::ProductSerializer < ApplicationSerializer

  def product_type
    object.product_type.to_s
  end

  def repositories
    object.repositories.map do |repository|
      V3::RepositorySerializer.new(repository, base_url: base_url)
    end
  end

  attributes :id, :name, :identifier, :former_identifier, :version, :release_type, :arch,
             :friendly_name, :product_class, :cpe, :free, :description, :eula_url, :repositories, :product_type,
             :extensions, :recommended

  def extensions
    object.extensions.for_root_product(root_product).map do |extension|
      ::V3::ProductSerializer.new(extension, base_url: base_url, root_product: root_product).attributes
    end
  end

  def arch
    (object.arch == 'unknown') ? nil : object.arch
  end

  def eula_url
    if object.eula_url
      RMT::Misc.replace_uri_parts(object.eula_url, base_url + RMT::DEFAULT_MIRROR_URL_PREFIX)
    else
      ''
    end
  end

  def free
    # Everything is free on RMT :-)
    # Otherwise Yast and SUSEConnect will request a regcode when activating an extension
    true
  end

  def root_product
    @instance_options[:root_product] ||= object
  end

  def recommended
    object.recommended_for? root_product
  end

end
