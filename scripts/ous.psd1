# OUs en gebruikers om in te voeren bij labomgeving

@{
    # Name = OU wordt direct onder het domein aangemaakt
    OUs = @(
        @{ Name = 'IT' }
        @{ Name = 'Lectoren' }
        @{ Name = 'Studenten' }
    )

    # OU = een van de OUs, Admin -> True?: Wordt toegevoegd aan de groep Domain Admins
    Users = @(
        @{ SamAccountName = 'jelle.devreeze';  GivenName = 'Jelle';  Surname = 'De Vreeze';  OU = 'IT';    Admin = $true;  Password = 'Admin123!' }
        @{ SamAccountName = 'jeroen.janssens';  GivenName = 'Jeroen';   Surname = 'Janssens'; OU = 'IT';    Admin = $true;  Password = 'Admin123!' }
        @{ SamAccountName = 'sanne.maes';     GivenName = 'Sanne';  Surname = 'Maes';     OU = 'Lectoren'; Admin = $false; Password = 'User123!' }
        @{ SamAccountName = 'ben.scout';   GivenName = 'Ben';   Surname = 'Scout';  OU = 'Studenten';    Admin = $false; Password = 'User123!' }
    )
}
