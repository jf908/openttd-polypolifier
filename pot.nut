require("module.nut")
require("setting_names.nut")

class Pot extends Module
{
	quarterly_rate = 0.05;
	content = null;
	cap_spill = null;
	cap_overdraft = null;
	grace_margin = 50000;
	grace_proportion = 0.75;

	constructor()
	{
		::Module.constructor();
		content = GetSetting(::POT_INITIAL_CONTENT);
	}

	function Save()
	{
		return {
			content = content,
		}
	}

	function Load(version, data)
	{
		parent.Load(version, data);
		content = data.content;
	}

	function Refresh()
	{
		quarterly_rate = GetPercentageSetting(::POT_RATE);
		cap_spill = GetSetting(::POT_CAP);
		cap_overdraft = -GetSetting(::POT_OVERDRAFT_CAP);
		grace_margin = GetSetting(::GRACE_MARGIN);
		grace_proportion = GetPercentageSetting(::GRACE_PROPORTION);
	}

	function OnQuarter(_)
	{
		if (content < 0)
		{
			content *= 1 + quarterly_rate;
			if (content < cap_overdraft)
				content = cap_overdraft;
		}
		else if (cap_spill < content)
			content = cap_spill;
	}

	function IsInOverdraft()
	{
		return content < 0;
	}

	function GetOverdraft()
	{
		if (content < 0)
			return -content;
		return 0;
	}

	function MeansTestedTax(company, amount)
	{
		if (typeof amount == "float")
			amount = amount.tointeger();

		if (CanMeansTestedlyTax(company, amount))
		{
			Tax(company, amount);
			content += amount;
		}
	}

	function CanMeansTestedlyTax(company, amount)
	{
		if (typeof amount == "float")
			amount - amount.tointeger();
		return
			amount + grace_margin <= company.profit
			&& company.profit - amount <= grace_proportion * company.profit;
	}

	function Tax(company, amount)
	{
		if (typeof amount == "float")
			amount = amount.tointeger();
		Pay(company, -amount);
	}

	function Grant(company, amount)
	{
		if (typeof amount == "float")
			amount = amount.tointeger();

		if (!CanGrant(amount))
			return false;

		content -= amount;
		Pay(company, amount);

		return true;
	}

	function CanGrant(amount)
	{
		return cap_overdraft <= content - amount;
	}

	/* function CanGrantWithExtraTax(amount, extra_tax) */
	/* { */
	/* 	if (typeof amount == "float") */
	/* 		amount = amount.tointeger(); */
	/* 	if (typeof extra_tax == "float") */
	/* 		extra_tax = extra_tax.tointeger(); */
	/* 	return content + extra_tax - amount >= cap_overdraft */
	/* } */

	function Pay(company, amount)
	{
		if (amount >= 0)
			GSLog.Error("Paying $" + amount + " to " + company.name + " (" + company.id + ")");
		else
			GSLog.Error("Paying -$" + -amount + " to " + company.name + " (" + company.id + ")");
		if (!GSCompany.ChangeBankBalance(company.id, amount, GSCompany.EXPENSES_OTHER, company.hq)) // TODO: check this actually works?
			GSLog.Error("Failed to change bank balance of " + company.id + " by £" + amount);
	}

	function OnEvent(args)
	{
		local et = args[0];
		local ev = args[1];
		switch (et)
		{
			case GSEvent.ET_COMPANY_NEW:
				CompanyNumChange(true);
				break;
			case GSEvent.ET_COMPANY_MERGER:
				CompanyNumChange(false);
				break;
			case GSEvent.ET_COMPANY_BANKRUPT:
				CompanyNumChange(false);
				break;
		}
	}

	function CompanyNumChange(increase)
	{
		content += (increase ? 1 : -1) * GetSetting(::POT_COMPANY_CHANGE_BOOST);
	}
}
