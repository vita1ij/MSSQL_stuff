
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
,unique_columns(unique_table, unique_column)
as
(
	select 
		fk.dependant_tbl, fk.dependant_column
	from x_foreign_keys fk
		join information_schema.table_constraints cns on cns.TABLE_NAME = fk.dependant_tbl
		inner join information_schema.constraint_column_usage CC on cns.Constraint_Name = CC.Constraint_Name and CC.COLUMN_NAME = fk.dependant_column
	where CONSTRAINT_TYPE = 'Unique'	
)
,x_foreign_joins(base_tbl, dependant_tbl, join_script, dependant_column)
as
(
	select 
		base_tbl,
		dependant_tbl,
		base_column + '=' + dependant_column,
		dependant_column
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
,update_scripts(dependant_tbl, script)
as
(
	select dependant_tbl,
	'UPDATE ' + dependant_tbl + ' SET ' + dependant_column + ' = ' + @value_remaining 
		+ ' FROM ' + base_tbl + ' join ' + dependant_tbl + ' on ' + join_script
		+ ' WHERE ' + @condition_merge
	from x_foreign_joins f
	where not exists(select top 1 1 from unique_columns u where u.unique_table = f.dependant_tbl and unique_column = dependant_column)
)
,updateWithChecks_scripts(dependant_tbl, script)
as
(
	select dependant_tbl,
	'UPDATE ' + dependant_tbl + ' SET ' + dependant_column + ' = ' + @value_remaining 
		+ ' FROM ' + base_tbl + ' join ' + dependant_tbl + ' on ' + join_script
		+ ' WHERE ' + @condition_merge
		+ ' AND not exists (select top 1 1 from ' + dependant_tbl + ' where ' + dependant_column + ' = ' + @value_remaining + '); '
		+ 'DELETE ' + dependant_tbl 
		+ ' FROM ' + base_tbl + ' join ' + dependant_tbl + ' on ' + join_script
		+ ' WHERE ' + @condition_merge
	from x_foreign_joins f
	join unique_columns u on u.unique_table = f.dependant_tbl and unique_column = dependant_column
)
select * from update_scripts
union all
select * from updateWithChecks_scripts