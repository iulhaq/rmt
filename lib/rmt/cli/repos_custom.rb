class RMT::CLI::ReposCustom < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'add URL NAME PRODUCT_ID', 'Add a new custom repository to a product'
  def add(url, name, product_id)
    product = find_product(product_id)
    previous_repository = Repository.find_by(external_url: url)

    if product.nil?
      warn "Cannot find product by id #{product_id}."
      return
    elsif previous_repository
      warn 'A repository by this URL already exists.'
      return
    end

    begin
      repository_service.create_repository!(product, url, {
        name: name,
        mirroring_enabled: product.mirror?,
        autorefresh: 1,
        enabled: 0
      }, custom: true)

      puts 'Successfully added custom repository.'
    rescue RepositoryService::InvalidExternalUrl => e
      warn "Invalid URL \"#{e.message}\" provided."
    end
  end

  desc 'list', 'List all custom repositories'
  def list
    repositories = Repository.only_custom

    if repositories.empty?
      warn 'No custom repositories found.'
    else
      puts array_to_table(repositories, {
        id: 'ID',
        name: 'Name',
        external_url: 'URL',
        enabled: 'Mandatory?',
        mirroring_enabled: 'Mirror?',
        last_mirrored_at: 'Last Mirrored'
      })
    end
  end
  map ls: :list

  desc 'remove ID', 'Remove a custom repository'
  def remove(id)
    repository = find_repository(id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return
    end

    repository.destroy!
    puts "Removed custom repository by id \"#{repository.id}\"."
  end
  map rm: :remove

  desc 'products ID', 'Shows products attached to a custom repository'
  def products(id)
    repository = find_repository(id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return
    end

    products = repository.products

    if products.empty?
      warn 'No products attached to repository.'
      return
    end
    puts array_to_table(products, {
      id: 'Product ID',
      name: 'Product Name'
    })
  end

  desc 'attach ID PRODUCT_ID', 'Attach an existing custom repository to a product'
  def attach(id, product_id)
    product, repository = attach_or_detach(id, product_id) || return
    repository_service.attach_product!(product, repository)
    puts 'Attached repository to product'
  end

  desc 'detach ID PRODUCT_ID', 'Detach an existing custom repository from a product'
  def detach(id, product_id)
    product, repository = attach_or_detach(id, product_id) || return
    repository_service.detach_product!(product, repository)
    puts 'Detached repository from product'
  end

  private

  def find_repository(id)
    repository = Repository.find_by(id: id)
    return nil if repository && !repository.custom?
    repository
  end

  def find_product(id)
    Product.find_by(id: id)
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

  def attach_or_detach(id, product_id)
    repository = find_repository(id)
    product = find_product(product_id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return false
    elsif product.nil?
      warn "Cannot find product by id \"#{product_id}\"."
      return false
    end

    [product, repository]
  end

end
