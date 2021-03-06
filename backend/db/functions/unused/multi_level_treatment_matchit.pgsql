CREATE OR REPLACE FUNCTION multi_level_treatment_matchit(
  sourceTable TEXT,        -- input table name
  primaryKey TEXT,         -- source table's primary key
  treatment TEXT,          -- treatment column name
  treatmentLevels INTEGER, -- possible levels for given treatment
  covariatesArr TEXT[],    -- array of covariate column names for given treatment
  outputTable TEXT         -- output table name
) RETURNS TEXT AS $func$
DECLARE
  commandString TEXT;
  covariate TEXT;
  columnName TEXT;
BEGIN
  commandString := 'WITH subclasses as (SELECT '
    || ' max(' || primaryKey || ') AS subclass_' || primaryKey;

  FOREACH covariate IN ARRAY covariatesArr LOOP
    commandString = commandString || ', ' || quote_ident(covariate) || ' AS ' || quote_ident(covariate) || '_matched';
  END LOOP;

  commandString = commandString || ' FROM ' || quote_ident(sourceTable) || ' GROUP BY ';

  FOREACH covariate IN ARRAY covariatesArr LOOP
    commandString = commandString || quote_ident(covariate) || '_matched, ';
  END LOOP;

  -- use substring here to chop off last comma
  commandString = substring( commandString from 0 for (char_length(commandString) - 1) );
    
  commandString = commandString || ' HAVING count(distinct ' || treatment || ') = ' || treatmentLevels
    || ') SELECT * FROM subclasses, ' || quote_ident(sourceTable) || ' st WHERE';

  FOREACH covariate IN ARRAY covariatesArr LOOP
    commandString = commandString || ' subclasses.' || quote_ident(covariate) || '_matched = st.' || quote_ident(covariate) || ' AND';
  END LOOP;

  -- use substring here to chop off last `AND`
  commandString = substring( commandString from 0 for (char_length(commandString) - 3) );

  -- EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS %s', outputTable);

  commandString = 'CREATE MATERIALIZED VIEW ' || outputTable
    || ' AS ' || commandString || ' WITH DATA;';
  RAISE NOTICE '%', commandString;
  EXECUTE commandString;

  RETURN 'Match successful and materialized in ' || outputTable || '!';
END;
$func$ LANGUAGE plpgsql;
