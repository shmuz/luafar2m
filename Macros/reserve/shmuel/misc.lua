-- * On some systems or configurations the numpad's keys come having wrong codes
--   e.g. '+' comes when 'Add' is pressed, etc.
-- * This macro "fixes" that.
-- * far2l has the same "fix" hard-coded internally (see https://github.com/elfmz/far2l/issues/2311)
-- * See far2m issue https://github.com/shmuz/far2m/issues/80
Macro {
  description="Select operations on problematic systems";
  area="Shell"; key="+ - *";
  flags="EmptyCommandLine";
  action=function()
    local pkey = mf.akey(1)
    if     pkey == '+' then Keys("Add")
    elseif pkey == '-' then Keys("Subtract")
    elseif pkey == '*' then Keys("Multiply")
    end
  end;
}
