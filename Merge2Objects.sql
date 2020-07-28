
declare @MergeTable varchar(max) = 'Table_name'
declare @condition_merge varchar(max) = 'pk_column = @id_from'
declare @value_remaining varchar(max) = '@id_to'
declare @tbl int
select @tbl = object_id from sys.tables where name = @MergeTable

;with x_foreign_keys(base_tbl_id, base_tbl, base_column_id, base_column, dependant_tbl_id, dependant_tbl, dependant_column_id, dependant_column)
as
(
	select 
		referenced_object_id,
		convert(varchar(max),child_table.name),
		child_column.column_id,
		convert(varchar(max),child_column.name),
		parent_table.object_id,
		convert(varchar(max),parent_table.name),
		parent_column.column_id,
		convert(varchar(max),parent_column.name)
	from sys.foreign_key_columns fkc
	join sys.tables child_table on child_table.object_id = fkc.referenced_object_id
	join sys.columns parent_column on parent_column.column_id = parent_column_id and parent_column.object_id = fkc.parent_object_id 
	join sys.columns child_column  on child_column.column_id = referenced_column_id and child_column.object_id = fkc.referenced_object_id
	join sys.tables parent_table on parent_table.object_id = fkc.parent_object_id
	where convert(varchar(max),child_table.name) = @MergeTable
)
,x_foreign_joins(base_tbl, dependant_tbl, join_script, dependant_column)
as
(
	select 
		base_tbl,
		dependant_tbl,
		(select 
			' or ' + base_column + '=' + dependant_column 
		from 
			x_foreign_keys y 
		where 
			x.base_column_id = y.base_column_id 
			and x.base_tbl_id = y.base_tbl_id 
			and x.dependant_tbl_id = y.dependant_tbl_id 
		for xml path('')
		) 
		,dependant_column
	from x_foreign_keys x
		group by 
		base_tbl,
		base_tbl_id, 
		base_column,
		base_column_id, 
		dependant_tbl,
		dependant_tbl_id,
		dependant_column
)
,x_foreign_joins_formatted(base_tbl, dependant_tbl, join_script, dependant_column)
as
(
	select
		base_tbl, 
		dependant_tbl, 
		RIGHT(join_script, LEN(join_script)-4),
		dependant_column
	from x_foreign_joins
)
,update_scripts(dependant_tbl, script)
as
(
	select dependant_tbl,
	'UPDATE ' + dependant_tbl + ' SET ' + dependant_column + ' = ' + @value_remaining 
		+ ' FROM ' + base_tbl + ' join ' + dependant_tbl + ' on ' + join_script
		+ ' WHERE ' + @condition_merge
	from x_foreign_joins_formatted
)
select * from update_scripts
