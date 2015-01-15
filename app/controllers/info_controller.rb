require 'uri'
require 'json'
require 'govuk/client/metadata_api'
require 'performance_data/metrics'

class InfoController < ApplicationController
  before_filter :set_expiry, only: :show

  def show
    slug = URI.encode(params[:slug])
    metadata = GOVUK::Client::MetadataAPI.new.info(slug)
    if metadata
      @artefact = metadata.fetch("artefact")
      @needs = metadata.fetch("needs")
      if InfoFrontend::FeatureFlags.needs_to_show == :only_validated
        @needs.select! { |need| InfoFrontend::FeatureFlags.validated_need_ids.include?(need["id"]) }
      end
      part_urls = []
      details = @artefact.fetch("details")
      if details.key?("parts")
        tmp = details.fetch("parts")
        if tmp == nil
          part_urls = []
        else
          part_urls = tmp
        end
      end
      calculated_metrics = metrics_from(@artefact, metadata.fetch("performance"), part_urls)
      @lead_metrics = calculated_metrics[:lead_metrics]
      @per_page_metrics = calculated_metrics[:per_page_metrics]
      logger.debug(@per_page_metrics)
      @show_needs = [:all, :only_validated].include?(InfoFrontend::FeatureFlags.needs_to_show)

    else
      response.headers[Slimmer::Headers::SKIP_HEADER] = "1"
      head 404
    end
  end

private
  def metrics_from(artefact, performance_data, part_urls = [])
    all_metrics = AllMetrics.new(performance_data)
    { lead_metrics: all_metrics.lead_metrics }.tap do |metrics|
      metrics[:per_page_metrics] = {}
      part_urls.each do |part_url|
        path = URI(part_url["web_url"]).path
        metrics[:per_page_metrics][path] = all_metrics.metrics_for(path)
      end
      if metrics[:per_page_metrics] == {}
        metrics[:per_page_metrics] = nil
      end
    end
  end
end

class AllMetrics
  def initialize(performance_data)
    @performance_data = performance_data
  end

  def lead_metrics
    PerformanceData::Metrics.new(
      unique_pageviews: performance_data_for("page_views").map {|l| l["value"] },
      exits_via_search: performance_data_for("searches").map {|l| l["value"] },
      problem_reports: performance_data_for("problem_reports").map {|l| l["value"] },
      search_terms: performance_data_for("search_terms").map {|term| { keyword: term["Keyword"], total: term["TotalSearches"] } },
    )
  end

  def metrics_for(path)
    PerformanceData::Metrics.new(
      unique_pageviews: performance_data_for("page_views", path).map {|l| l["value"] },
      exits_via_search: performance_data_for("searches", path).map {|l| l["value"] },
      problem_reports: performance_data_for("problem_reports", path).map {|l| l["value"] },
    )
  end

  def performance_data_for(metric, path = nil)
    data = @performance_data[metric] || []
    path ? data.select { |record| record["path"] == path } : data
  end
end
