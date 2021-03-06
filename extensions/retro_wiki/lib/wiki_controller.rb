#--
# Copyright (C) 2009 Dimitrij Denissenko
# Please read LICENSE document for more information.
#++
class WikiController < ProjectAreaController
  retrospectiva_extension('retro_wiki')
  
  menu_item :wiki do |i|
    i.label = N_('Wiki')
    i.rank = 50
    i.path = lambda do |project|
      project_wiki_page_path(project, project.wiki_title)
    end
  end

  require_permissions :wiki_pages,
    :view   => ['index', 'show', 'files', 'file'],
    :update => ['edit', 'update'],
    :rename => ['rename', 'update_title'],
    :delete => ['destroy'],
    :upload => ['upload']

  before_filter :find_page_or_redirect, :only => :show
  before_filter :find_page!, :only => [:rename, :update_title, :destroy]
  before_filter :find_or_build_page, :only => [:edit, :update]
  
  def index
    @pages = Project.current.wiki_pages.paginate options_for_paginate 

    respond_to do |format|
      format.html
      format.rss  { render_rss(WikiPage, @pages) }
      format.xml  { render :xml => @pages.to_xml }
    end
  end
  
  def show
    version = find_version(params[:version])
    @wiki_page = version if version

    respond_to do |format|
      format.html
      format.xml  { render :xml => @wiki_page.to_xml(:root => 'wiki_page') }
    end  
  end
  
  def edit
    version = find_version(params[:version])
    @wiki_page.content = version.content if version
    @wiki_page.author = cached_user_attribute(:name, 'Anonymous')
  end
  
  def update
    respond_to do |format|
      if @wiki_page.update_attributes(params[:wiki_page])
        flash[:notice] = @wiki_page.number == 1 ?
           _('Page was successfully created.') :
           _('Page was successfully updated.')
        cache_user_attributes!(:name => @wiki_page.author)
        
        format.html { redirect_to [Project.current, @wiki_page] }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @wiki_page.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def rename
  end

  def update_title
    @wiki_page.title = params[:title]

    respond_to do |format|
      if @wiki_page.save
        flash[:notice] = _('Page was successfully updated.')
        format.html { redirect_to [Project.current, @wiki_page] }
        format.xml  { head :ok }
      else        
        format.html { render :action => "rename" }
        format.xml  { render :xml => @wiki_page.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @wiki_page.destroy

    respond_to do |format|
      format.html { redirect_to project_wiki_page_path(Project.current, Project.current.wiki_title) }
      format.xml  { head :ok }
    end
  end
  
  protected
  
    def find_page_or_redirect
      @wiki_page = Project.current.wiki_pages.find_by_title params[:id], :include => [:versions]
      if @wiki_page
      elsif params[:id].present? and permitted?(:wiki_pages, :update)
        redirect_to edit_project_wiki_page_path(Project.current, params[:id])
      else
        redirect_to project_wiki_pages_path(Project.current)
      end
    end

    def find_page!
      @wiki_page = Project.current.wiki_pages.find_by_title! params[:id]
    end

    def find_or_build_page
      @wiki_page = Project.current.wiki_pages.find_or_build(params[:id])     
    end

    def options_for_paginate
      { :page => ( rss_request? ? 1 : params[:page] ), 
        :per_page => ( rss_request? ? 10 : nil ),
        :order => pagination_order }
    end
        
    def pagination_order
      rss_request? || params[:order] == 'recent' ? 'wiki_pages.updated_at DESC' : 'wiki_pages.title'
    end

  private

    def find_version(number)
      number.to_i > 0 ? @wiki_page.versions[number.to_i - 1] : nil
    end
end
