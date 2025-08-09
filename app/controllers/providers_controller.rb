class ProvidersController < ApplicationController
  def index
    @providers = Provider.all.load_async
    @provider = Provider.new
    @predefined_providers = Provider::PREDEFINED_PROVIDERS
  end

  def new
    @provider = Provider.new
    @predefined_providers = Provider::PREDEFINED_PROVIDERS
  end

  def create
    @provider = Provider.new(provider_params)
    set_predefined_attributes

    if @provider.save
      render turbo_stream: [
        turbo_stream.append("providers", partial: "providers/provider", locals: { provider: @provider }),
        turbo_stream.replace("provider_form", partial: "providers/form", locals: { provider: Provider.new(status: :active), predefined_providers: Provider::PREDEFINED_PROVIDERS }),
        turbo_stream.update("notice", partial: "shared/notice", locals: { message: "Provider created successfully." })
      ]
    else
      render turbo_stream: turbo_stream.replace("provider_form", partial: "providers/form", locals: { provider: @provider, predefined_providers: Provider::PREDEFINED_PROVIDERS })
    end
  end

  def edit
    @provider = Provider.find(params[:id])
    @predefined_providers = Provider::PREDEFINED_PROVIDERS
  end

  def update
    @provider = Provider.find(params[:id])
    set_predefined_attributes

    if @provider.update(provider_params)
      render turbo_stream: [
        turbo_stream.replace("provider_#{@provider.id}", partial: "providers/provider", locals: { provider: @provider }),
        turbo_stream.update("notice", partial: "shared/notice", locals: { message: "Provider updated successfully." })
      ]
    else
      render turbo_stream: turbo_stream.replace("provider_form", partial: "providers/form", locals: { provider: @provider, predefined_providers: Provider::PREDEFINED_PROVIDERS })
    end
  end

  def destroy
    @provider = Provider.find(params[:id])
    @provider.destroy
    render turbo_stream: [
      turbo_stream.remove("provider_#{@provider.id}"),
      turbo_stream.update("notice", partial: "shared/notice", locals: { message: "Provider deleted successfully." })
    ]
  end

  private

  def provider_params
    params.require(:provider).permit(:name, :description, :api_key, :api_secret, :provider_type, :status)
  end

  def set_predefined_attributes
    return unless (predefined = Provider::PREDEFINED_PROVIDERS[params[:provider][:provider_type]])

    @provider.api_url = predefined[:api_url]
    @provider.api_version = predefined[:api_version]
    @provider.status = :active unless @provider.persisted? # Only set status for new records

    # Ensure the unused key field is set to a placeholder to satisfy validations
    @provider.api_key = predefined[:key_field] == :api_key ? @provider.api_key : "placeholder"
    @provider.api_secret = predefined[:key_field] == :api_secret ? @provider.api_secret : "placeholder"
  end
end
