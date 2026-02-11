class DailyImportJob < ApplicationJob
  queue_as :default

  def perform
    unless AppConfiguration.instance.daily_import_enabled?
      Rails.logger.info "DailyImportJob: Skipped (global daily import disabled)"
      return
    end
    projects_to_import = Project.where(daily_import_enabled: true).where.not(redmine_project_id: [ nil, "" ])
    unless projects_to_import.exists?
      Rails.logger.info "DailyImportJob: Skipped (no projects with Redmine link)"
      return
    end

    yesterday = Date.yesterday
    base = RedmineService::BASE_URL.sub(/\/*\z/, "")

    projects_to_import.find_each do |project|
      run = project.daily_import_runs.create!(status: "running", started_at: Time.current)
      lines = []
      begin
        path_and_query = RedmineService.build_issues_url(
          RedmineService::BASE_URL,
          project_id: project.redmine_project_id,
          created_on_from: yesterday,
          created_on_to: yesterday
        )
        full_issues_url = "#{base}#{path_and_query}"

        lines << "[#{Time.current.strftime('%H:%M:%S')}] Import Redmine #{project.redmine_project_id} -> #{project.name} for #{yesterday}"
        Rails.logger.info "DailyImportJob: #{lines.last}"

        importer = RedmineBulkImportService.new(project.id, issues_url: full_issues_url)
        success = importer.import do |count|
          lines << "[#{Time.current.strftime('%H:%M:%S')}] Found #{count} tasks matching '4. Testing'."
          Rails.logger.info "DailyImportJob: #{lines.last}"
        end

        if success
          lines << "[#{Time.current.strftime('%H:%M:%S')}] #{project.name} — Imported: #{importer.imported_tasks.count}, Skipped: #{importer.skipped_count}"
          Rails.logger.info "DailyImportJob: #{lines.last}"
          run.update!(
            status: "success",
            finished_at: Time.current,
            imported_count: importer.imported_tasks.count,
            skipped_count: importer.skipped_count,
            log_output: lines.join("\n")
          )
          notify_cronjob(project, run, success: true, imported: importer.imported_tasks.count, skipped: importer.skipped_count)
        else
          err = importer.errors.join(", ")
          lines << "[#{Time.current.strftime('%H:%M:%S')}] FAILED — #{err}"
          run.update!(
            status: "failed",
            finished_at: Time.current,
            imported_count: importer.imported_tasks.count,
            skipped_count: importer.skipped_count,
            error_message: err,
            log_output: lines.join("\n")
          )
          notify_cronjob(project, run, success: false, error: err)
        end
      rescue StandardError => e
        lines << "[#{Time.current.strftime('%H:%M:%S')}] Error: #{e.message}"
        run.update!(
          status: "failed",
          finished_at: Time.current,
          error_message: e.message,
          log_output: lines.join("\n")
        )
        notify_cronjob(project, run, success: false, error: e.message)
        Rails.logger.error "DailyImportJob: #{e.message}"
      end
    end
  end

  private

  def notify_cronjob(project, run, success:, imported: nil, skipped: nil, error: nil)
    title = "Daily Import: #{project.name}"
    message = if success
      "Imported #{imported}, skipped #{skipped} tasks."
    else
      "Failed: #{error.to_s.truncate(120)}"
    end
    link = "/projects/#{project.id}/daily_import_runs/#{run.id}"
    Notification.create!(category: "cronjob", title: title, message: message, link: link)
  end
end
